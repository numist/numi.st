# ABOUTME: Annotates external text links in rendered HTML with popover previews showing the
# ABOUTME: linked page's title and self-hosted favicon, fetched at build time and cached in _link_previews.
require 'jekyll'
require 'net/http'
require 'nokogiri'
require 'cgi'
require 'fileutils'
require 'set'
require 'yaml'

module Jekyll
  module LinkPreviews
    CACHE_DIR = '_link_previews'
    FAVICON_URL_DIR = '/assets/img/favicons'
    USER_AGENT = 'numi.st link preview builder'
    TIMEOUT = 5
    MAX_REDIRECTS = 5

    # Elements that may appear inside a link without it ceasing to be a text link.
    TEXT_ELEMENTS = %w[abbr b bdi bdo br cite code del dfn em i ins kbd mark q s samp small span strong sub sup time u var wbr].freeze

    # Leading bytes of the favicon formats accepted when the content type doesn't identify one.
    FAVICON_SIGNATURES = {
      'ico' => /\A\x00\x00\x01\x00/n,
      'png' => /\A\x89PNG\r\n\x1a\n/n,
      'gif' => /\AGIF8[79]a/n,
      'jpg' => /\A\xFF\xD8\xFF/n,
      'webp' => /\ARIFF.{4}WEBP/mn
    }.freeze

    FAVICON_EXTENSIONS = {
      'image/png' => 'png',
      'image/x-icon' => 'ico',
      'image/vnd.microsoft.icon' => 'ico',
      'image/gif' => 'gif',
      'image/jpeg' => 'jpg',
      'image/webp' => 'webp'
    }.freeze

    VOID_ELEMENTS = %w[area base br col embed hr img input link meta param source track wbr].freeze
    RAW_TEXT_ELEMENTS = %w[script style textarea].freeze

    # The rest of a tag after its name, where quoted attribute values may contain '>' or '<!--'.
    TAG_ATTRIBUTES = %q{(?:[^>"']|"[^"]*"|'[^']*')*}

    # Matches the markup that matters for tracking open elements: comments, doctypes and CDATA
    # (all skipped), and start and end tags.
    TOKEN = %r{
      <!--.*?--> |
      (?<unterminated_comment><!--) |
      <!\[CDATA\[.*?\]\]> |
      <![^>]*> |
      <(?<end>/)?(?<name>[a-z][^\s/>]*)(?<attributes>#{TAG_ATTRIBUTES})>
    }mix

    class MarkupError < StandardError; end

    def self.external?(href)
      uri = URI.parse(href.to_s)
      !uri.host.nil? && [nil, 'http', 'https'].include?(uri.scheme&.downcase)
    rescue URI::InvalidURIError
      false
    end

    def self.text_only?(link)
      !link.text.strip.empty? && link.css('*').all? { |element| TEXT_ELEMENTS.include?(element.name) }
    end

    # Decodes using the response's charset, else the document's own declaration, else UTF-8.
    def self.parse(body, charset)
      Nokogiri::HTML(body, nil, charset || Nokogiri::HTML4::EncodingReader.detect_encoding(body) || 'UTF-8')
    end

    def self.extract_title(body, charset)
      document = parse(body, charset)
      candidates = [document.at_css('title')&.text, document.at_css('meta[property="og:title"]')&.[]('content')]
      candidates.map { |candidate| candidate&.gsub(/\s+/, ' ')&.strip }.find { |candidate| candidate && !candidate.empty? }
    end

    # Returns candidate favicon URLs for a page, most preferred first, ending with the host's /favicon.ico.
    def self.icon_urls(body, charset, page_url)
      links = body ? parse(body, charset).css('link[rel][href]') : []
      rels = ->(link) { link['rel'].downcase.split }
      icons = links.select { |link| rels.(link).include?('icon') } +
              links.select { |link| (rels.(link) & %w[apple-touch-icon apple-touch-icon-precomposed]).any? }
      urls = icons.map do |link|
        URI.join(page_url, link['href'].strip).to_s
      rescue URI::Error
        nil
      end
      (urls.compact.grep(%r{\Ahttps?://}) + [URI.join(page_url, '/favicon.ico').to_s]).uniq
    end

    # Annotates external text links inside <article> elements, leaving the rest of the HTML byte-for-byte intact.
    # Raises MarkupError, naming the page, if the HTML's elements aren't properly closed and nested.
    def self.annotate(html, previews, page: nil)
      edits = []
      each_element(html, page) do |name, start, opening_tag_end, finish, in_article|
        next unless name == 'a' && in_article

        link = Nokogiri::HTML5.fragment(html[start...finish]).at_css('a')
        next unless link && external?(link['href']) && text_only?(link)

        edits << [start, opening_tag_end, annotated_opening_tag(link, previews)]
      end
      apply_edits(html, edits)
    end

    # Yields each element as it closes: its name, the offsets of its start, the end of its opening
    # tag, and its end, and whether it is inside an <article>.
    def self.each_element(html, page)
      open_elements = []
      position = 0
      while (token = TOKEN.match(html, position))
        position = token.end(0)
        markup_error(html, page, token.begin(0), 'unterminated comment') if token[:unterminated_comment]
        next unless token[:name]

        name = token[:name].downcase
        if token[:end]
          element = open_elements.pop
          markup_error(html, page, token.begin(0), "stray </#{name}>") unless element
          unless element[:name] == name
            opened_on = line_number(html, element[:start])
            markup_error(html, page, token.begin(0), "</#{name}> does not close <#{element[:name]}> from line #{opened_on}")
          end
          in_article = open_elements.any? { |ancestor| ancestor[:name] == 'article' }
          yield name, element[:start], element[:opening_tag_end], position, in_article
        elsif RAW_TEXT_ELEMENTS.include?(name)
          closing_tag = %r{</#{name}\s*>}i.match(html, position)
          markup_error(html, page, token.begin(0), "<#{name}> is never closed") unless closing_tag
          position = closing_tag.end(0)
        elsif !VOID_ELEMENTS.include?(name) && !token[:attributes].end_with?('/')
          open_elements << { name: name, start: token.begin(0), opening_tag_end: position }
        end
      end
      return if open_elements.empty?

      markup_error(html, page, open_elements.last[:start], "<#{open_elements.last[:name]}> is never closed")
    end

    def self.markup_error(html, page, offset, problem)
      raise MarkupError, "#{page}:#{line_number(html, offset)}: #{problem}"
    end

    def self.line_number(html, offset)
      html[0...offset].count("\n") + 1
    end

    # Replaces each [start, end, text] span (in document order) without touching the rest of the string.
    def self.apply_edits(html, edits)
      return html if edits.empty?

      output = +''
      position = 0
      edits.each do |start, finish, text|
        output << html[position...start] << text
        position = finish
      end
      output << html[position..]
    end

    # A link's own title attribute overrides the cached page title, and is removed so its
    # native tooltip doesn't compete with the popover.
    def self.annotated_opening_tag(link, previews)
      href = link['href']
      inline_title = link.remove_attribute('title')&.value.to_s.gsub(/\s+/, ' ').strip
      title = inline_title.empty? ? previews.title(href) : inline_title
      link['class'] = [link['class'], 'link-preview'].compact.join(' ')
      link['target'] ||= '_blank'
      link['rel'] = (link['rel'].to_s.split | ['noopener']).join(' ')
      link['data-bs-content'] = popover_content(href, title || href, previews.favicon(href))
      attributes = link.attribute_nodes.map { |attribute| %( #{attribute.name}="#{CGI.escapeHTML(attribute.value)}") }
      "<a#{attributes.join}>"
    end

    def self.popover_content(href, title, favicon)
      image = favicon ? %(<img class="link-preview-favicon" src="#{FAVICON_URL_DIR}/#{favicon}" alt="">) : ''
      %(#{image}<a href="#{CGI.escapeHTML(href)}" target="_blank" rel="noopener">#{CGI.escapeHTML(title)}</a>)
    end

    def self.process(site)
      previews = Previews.new(File.join(site.source, CACHE_DIR))
      (site.pages + site.documents).each do |item|
        next unless item.output && item.output_ext == '.html'

        item.output = annotate(item.output, previews, page: item.relative_path)
      end
      previews.save
      previews.favicon_files.each { |name| site.static_files << FaviconFile.new(site, name) }
    end

    # Page titles (by URL) and favicons (by host), fetched on demand and cached on disk.
    # Cached entries are never refetched, so titles that couldn't be fetched can be filled in by hand.
    class Previews
      def initialize(directory, timeout: TIMEOUT)
        @directory = directory
        @timeout = timeout
        @titles = load('titles.yml')
        @favicons = load('favicons.yml')
        @pages = {}
        @untitled_urls_reported = Set.new
      end

      def title(href)
        url = page_url(href)
        @titles[url] = fetch_title(url) unless @titles.key?(url)
        entry = @titles[url] || {}
        if entry['title'].nil? && @untitled_urls_reported.add?(url)
          reason = entry['error'] ? " (#{entry['error']})" : ''
          Jekyll.logger.warn('Link preview:', "no title for #{url}#{reason}; set one in #{CACHE_DIR}/titles.yml")
        end
        entry['title']&.to_s
      end

      def favicon(href)
        url = page_url(href)
        host = URI(url).host.downcase
        return @favicons[host] if @favicons.key?(host)

        page = fetch_page(url)
        @favicons[host] = download_favicon(host, LinkPreviews.icon_urls(page[:body], page[:charset], page[:url]))
      end

      def favicon_files
        @favicons.values.compact
      end

      def save
        write('titles.yml', @titles)
        write('favicons.yml', @favicons)
      end

      private

      def page_url(href)
        uri = URI(href.start_with?('//') ? "https:#{href}" : href)
        uri.fragment = nil
        uri.to_s
      end

      def fetch_title(url)
        page = fetch_page(url)
        return { 'title' => nil, 'error' => page[:error] } if page[:error]

        title = LinkPreviews.extract_title(page[:body], page[:charset])
        title ? { 'title' => title } : { 'title' => nil, 'error' => 'no title found' }
      end

      def fetch_page(url)
        @pages[url] ||= begin
          response, final_url = get(url)
          raise "not HTML (#{response.content_type})" unless %w[text/html application/xhtml+xml].include?(response.content_type)

          { url: final_url, body: response.body, charset: response.type_params['charset'] }
        rescue StandardError => e
          { url: url, error: e.message }
        end
      end

      def get(url, redirects = MAX_REDIRECTS)
        uri = URI(url)
        options = { use_ssl: uri.scheme == 'https', open_timeout: @timeout, read_timeout: @timeout }
        response = Net::HTTP.start(uri.host, uri.port, **options) do |http|
          http.get(uri.request_uri, 'User-Agent' => USER_AGENT)
        end
        case response
        when Net::HTTPRedirection
          raise 'too many redirects' if redirects.zero?

          get(URI.join(url, response['location']).to_s, redirects - 1)
        when Net::HTTPSuccess
          [response, url]
        else
          raise "HTTP #{response.code}"
        end
      end

      def download_favicon(host, urls)
        urls.each do |url|
          response, = get(url)
          extension = favicon_extension(response)
          next unless extension

          name = "#{host}.#{extension}"
          FileUtils.mkdir_p(File.join(@directory, 'favicons'))
          File.binwrite(File.join(@directory, 'favicons', name), response.body)
          return name
        rescue StandardError
          next
        end
        Jekyll.logger.warn('Link preview:', "no favicon found for #{host}")
        nil
      end

      def favicon_extension(response)
        body = response.body.to_s.b
        return nil if body.empty?

        FAVICON_EXTENSIONS[response.content_type] ||
          FAVICON_SIGNATURES.find { |_, signature| signature.match?(body) }&.first
      end

      def load(name)
        path = File.join(@directory, name)
        File.exist?(path) ? YAML.safe_load_file(path) || {} : {}
      end

      def write(name, data)
        path = File.join(@directory, name)
        return if File.exist?(path) && YAML.safe_load_file(path) == data

        FileUtils.mkdir_p(@directory)
        File.write(path, data.sort.to_h.to_yaml(line_width: -1))
      end
    end

    # Publishes a cached favicon from _link_previews/favicons at FAVICON_URL_DIR.
    class FaviconFile < StaticFile
      def initialize(site, name)
        super(site, site.source, File.join(CACHE_DIR, 'favicons'), name)
      end

      def url
        File.join(FAVICON_URL_DIR, name)
      end
    end
  end
end

Jekyll::Hooks.register :site, :post_render do |site|
  Jekyll::LinkPreviews.process(site)
end

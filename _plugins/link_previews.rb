# ABOUTME: Annotates external text links in rendered HTML with popover previews showing the
# ABOUTME: linked page's title and self-hosted favicon, fetched at build time and cached in _link_previews.
require 'jekyll'
require 'net/http'
require 'nokogiri'
require 'cgi'
require 'digest'
require 'fileutils'
require 'yaml'

module Jekyll
  module LinkPreviews
    CACHE_DIR = '_link_previews'
    CACHE_FILE = 'links.yml'
    FIX_HINT = "set title:/favicon: in #{CACHE_DIR}/#{CACHE_FILE} (drop images in #{CACHE_DIR}/favicons/), " \
               'or delete the entry to retry'
    FAVICON_URL_DIR = '/assets/img/favicons'
    USER_AGENT = 'numi.st link preview builder'
    TIMEOUT = 5
    MAX_REDIRECTS = 5
    PAGE_SIZE_LIMIT = 1024 * 1024
    FAVICON_SIZE_LIMIT = 512 * 1024

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

    # The rest of a tag after its name: attributes, whose quoted values may contain '>' or '<!--' and whose
    # unquoted values may contain quotes, and slashes. Each attribute is matched atomically, so a tag
    # that doesn't parse fails quickly.
    TAG_ATTRIBUTES = %q{(?>\s*(?:[^\s"'>/=]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s"'>][^\s>]*))?|/))*\s*}

    # Matches the markup that matters for tracking open elements: comments, doctypes and CDATA
    # (all skipped), and start and end tags.
    TOKEN = %r{
      <!--.*?--> |
      (?<unterminated_comment><!--) |
      <!\[CDATA\[.*?\]\]> |
      <![^>]*> |
      <(?<end>/)?(?<name>[a-z][^\s/>]*)(?<attributes>#{TAG_ATTRIBUTES})> |
      (?<unparseable_tag></?[a-z])
    }mix

    class MarkupError < StandardError; end
    class CacheError < StandardError; end

    def self.external?(href)
      uri = URI.parse(ascii_url(href))
      !uri.host.nil? && [nil, 'http', 'https'].include?(uri.scheme&.downcase)
    rescue URI::InvalidURIError
      false
    end

    # Percent-encodes non-ASCII characters so that IRIs can be parsed and requested as URIs.
    def self.ascii_url(url)
      url.to_s.gsub(/[^\x00-\x7F]+/) { |characters| characters.bytes.map { |byte| format('%%%02X', byte) }.join }
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
      candidates.map { |candidate| squish(candidate) }.find { |candidate| !candidate.empty? }
    end

    # Returns candidate favicon URLs for a page, most preferred first, ending with the host's /favicon.ico.
    def self.icon_urls(body, charset, page_url)
      links = body ? parse(body, charset).css('link[rel][href]') : []
      rels = ->(link) { link['rel'].downcase.split }
      icons = links.select { |link| rels.(link).include?('icon') } +
              links.select { |link| (rels.(link) & %w[apple-touch-icon apple-touch-icon-precomposed]).any? }
      urls = icons.map do |link|
        URI.join(page_url, ascii_url(link['href'].strip)).to_s
      rescue URI::Error
        nil
      end
      (urls.compact.grep(%r{\Ahttps?://}) + [URI.join(page_url, '/favicon.ico').to_s]).uniq
    end

    # Annotates external text links inside <article> elements, leaving the rest of the HTML byte-for-byte intact.
    # Links whose href isn't written out in the page's source were generated (e.g. by Liquid), so they
    # aren't fetched or cached. Raises MarkupError, naming the page, if the HTML's elements aren't
    # properly closed and nested.
    def self.annotate(html, previews, page: nil, source: nil)
      edits = []
      untitled_generated_hrefs = []
      each_element(html, page) do |name, start, opening_tag_end, finish, in_article|
        next unless name == 'a' && in_article

        link = Nokogiri::HTML5.fragment(html[start...finish]).at_css('a')
        next unless link && external?(link['href']) && text_only?(link)

        generated = !source.nil? && !literal_in_source?(source, link['href'], html[start...opening_tag_end])
        untitled_generated_hrefs << link['href'] if generated && squish(link['title']).empty?
        edits << [start, opening_tag_end, annotated_opening_tag(link, previews, generated: generated)]
      end
      untitled_generated_hrefs.uniq.each do |href|
        Jekyll.logger.warn('Link preview:', "#{page} links to #{href}, which the page generates; " \
                                            'give the link an inline title, e.g. [text](url "Title")')
      end
      apply_edits(html, edits)
    end

    # Whether a link's href is written in the page's source as-is or HTML-escaped, rather than generated.
    def self.literal_in_source?(source, href, opening_tag)
      written = opening_tag.match(/\shref\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))/i)
      source.include?(href) || (!written.nil? && source.include?(written.captures.compact.first))
    end

    def self.squish(text)
      text.to_s.gsub(/\s+/, ' ').strip
    end

    # Yields each element as it closes: its name, the offsets of its start, the end of its opening
    # tag, and its end, and whether it is inside an <article>.
    def self.each_element(html, page)
      open_elements = []
      position = 0
      while (token = TOKEN.match(html, position))
        position = token.end(0)
        markup_error(html, page, token.begin(0), 'unterminated comment') if token[:unterminated_comment]
        markup_error(html, page, token.begin(0), 'unparseable tag') if token[:unparseable_tag]
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
        elsif !VOID_ELEMENTS.include?(name) && !self_closing?(token[:attributes])
          if name == 'a' && (outer_link = open_elements.find { |element| element[:name] == 'a' })
            opened_on = line_number(html, outer_link[:start])
            markup_error(html, page, token.begin(0), "<a> inside <a> from line #{opened_on}")
          end
          open_elements << { name: name, start: token.begin(0), opening_tag_end: position }
        end
      end
      return if open_elements.empty?

      markup_error(html, page, open_elements.last[:start], "<#{open_elements.last[:name]}> is never closed")
    end

    # Whether a tag ends in '/' on its own, rather than as the end of an unquoted attribute value.
    def self.self_closing?(attributes)
      attributes.match?(%r{(?:\A|[\s"'])/\z})
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
    def self.annotated_opening_tag(link, previews, generated: false)
      href = link['href']
      inline_title = squish(link.remove_attribute('title')&.value)
      if generated
        title = inline_title unless inline_title.empty?
      else
        title = inline_title.empty? ? previews.title(href) : inline_title
        favicon = previews.favicon(href)
      end
      link['class'] = [link['class'], 'link-preview'].compact.join(' ')
      link['target'] ||= '_blank'
      link['rel'] = (link['rel'].to_s.split | ['noopener']).join(' ')
      favicon_url = "#{FAVICON_URL_DIR}/#{favicon}" if favicon
      link['data-bs-content'] = popover_content(href, title || href, favicon_url)
      link['data-favicon'] = favicon_url if favicon_url
      attributes = link.attribute_nodes.map { |attribute| %( #{attribute.name}="#{CGI.escapeHTML(attribute.value)}") }
      "<a#{attributes.join}>"
    end

    def self.popover_content(href, title, favicon_url)
      image = favicon_url ? %(<img class="link-preview-favicon" src="#{CGI.escapeHTML(favicon_url)}" alt="">) : ''
      %(#{image}<a href="#{CGI.escapeHTML(href)}" target="_blank" rel="noopener">#{CGI.escapeHTML(title)}</a>)
    end

    def self.process(site)
      previews = Previews.new(File.join(site.source, CACHE_DIR))
      (site.pages + site.documents).each do |item|
        next unless item.output && item.output_ext == '.html'

        source_path = File.join(site.source, item.relative_path)
        source = File.read(source_path) if File.file?(source_path)
        item.output = annotate(item.output, previews, page: item.relative_path, source: source)
      end
      previews.report
      previews.save
      previews.favicon_files.each { |name| site.static_files << FaviconFile.new(site, name) }
    end

    # Each linked URL's page title and favicon, fetched on demand and cached on disk. Cached entries
    # are never refetched, so anything that couldn't be fetched can be filled in by hand.
    class Previews
      def initialize(directory, timeout: TIMEOUT)
        @directory = directory
        @timeout = timeout
        @entries = load
        @pages = {}
        @downloads = {}
        @title_needed = {}
      end

      def title(href)
        url = cache_key(href)
        @title_needed[url] = true
        entry(url)['title']&.to_s
      end

      def favicon(href)
        url = cache_key(href)
        @title_needed[url] ||= false
        name = entry(url)['favicon']
        name if name && File.exist?(favicon_path(name))
      end

      def favicon_files
        @entries.values.map { |entry| entry['favicon'] }.compact.uniq.select { |name| File.exist?(favicon_path(name)) }
      end

      # Warns once for each URL used in this build whose preview is missing anything.
      def report
        @title_needed.each do |url, title_needed|
          entry = @entries[url]
          problems = []
          problems << 'no title' if title_needed && entry['title'].nil?
          if entry['favicon'].nil?
            problems << 'no favicon'
          elsif !File.exist?(favicon_path(entry['favicon']))
            problems << "favicon #{entry['favicon']} not found in #{CACHE_DIR}/favicons/"
          end
          next if problems.empty?

          reason = entry['error'] ? " (#{entry['error']})" : ''
          Jekyll.logger.warn('Link preview:', "#{url}: #{problems.join(', ')}#{reason}; #{FIX_HINT}")
        end
      end

      def save
        path = File.join(@directory, CACHE_FILE)
        return if File.exist?(path) && YAML.safe_load_file(path) == @entries

        FileUtils.mkdir_p(@directory)
        File.write(path, @entries.sort.to_h.to_yaml(line_width: -1))
      end

      private

      def cache_key(href)
        (href.start_with?('//') ? "https:#{href}" : href).sub(/#.*/m, '')
      end

      def entry(url)
        @entries[url] = fetch_entry(url) unless @entries.key?(url)
        @entries[url]
      end

      def fetch_entry(url)
        page = fetch_page(url)
        title = page[:body] && LinkPreviews.extract_title(page[:body], page[:charset])
        favicon, favicon_error = discover_favicon(page)
        errors = {
          'title' => page[:error] || (title ? nil : 'no title found'),
          'favicon' => favicon_error
        }.compact.map { |part, error| "#{part}: #{error}" }
        entry = { 'title' => title, 'favicon' => favicon }
        entry['error'] = errors.join('; ') unless errors.empty?
        entry
      end

      def fetch_page(url)
        url = LinkPreviews.ascii_url(url)
        @pages[url] ||= begin
          response, body, final_url = get(url, PAGE_SIZE_LIMIT) do |headers|
            raise "not HTML (#{headers.content_type})" unless %w[text/html application/xhtml+xml].include?(headers.content_type)
          end
          { url: final_url, body: body, charset: response.type_params['charset'] }
        rescue StandardError => e
          { url: url, error: error_message(e) }
        end
      end

      # Returns the first of the page's candidate favicons that downloads, or nil and the last failure.
      def discover_favicon(page)
        error = nil
        LinkPreviews.icon_urls(page[:body], page[:charset], page[:url]).each do |url|
          download = (@downloads[url] ||= download_favicon(url))
          return [download[:name], nil] if download[:name]

          error = download[:error]
        end
        [nil, error]
      end

      def download_favicon(url)
        response, body, = get(url, FAVICON_SIZE_LIMIT) do |headers|
          raise "not an image (#{headers.content_type})" if headers.content_type.to_s.match?(%r{\Atext/|svg})
          raise 'too large' if headers.content_length.to_i > FAVICON_SIZE_LIMIT
        end
        raise 'too large' if body.bytesize > FAVICON_SIZE_LIMIT

        extension = !body.empty? && favicon_extension(response.content_type, body)
        return { error: "not an image (#{response.content_type})" } unless extension

        name = "#{Digest::SHA256.hexdigest(body)[0, 16]}.#{extension}"
        FileUtils.mkdir_p(File.join(@directory, 'favicons'))
        File.binwrite(favicon_path(name), body) unless File.exist?(favicon_path(name))
        { name: name }
      rescue StandardError => e
        { error: error_message(e) }
      end

      def favicon_extension(content_type, body)
        FAVICON_EXTENSIONS[content_type] || FAVICON_SIGNATURES.find { |_, signature| signature.match?(body) }&.first
      end

      def favicon_path(name)
        File.join(@directory, 'favicons', name)
      end

      def error_message(error)
        error.is_a?(Timeout::Error) ? error.class.name : error.message
      end

      # Fetches a URL, following redirects, and returns the response, up to just over limit bytes of
      # its body, and the final URL. The block can raise to reject a response before its body is read.
      def get(url, limit, redirects = MAX_REDIRECTS, &check)
        uri = URI(url)
        options = { use_ssl: uri.scheme == 'https', open_timeout: @timeout, read_timeout: @timeout }
        # Breaking out of request_get skips reading the rest of the body; leaving start closes the connection.
        response, body = Net::HTTP.start(uri.host, uri.port, **options) do |http|
          http.request_get(uri.request_uri, 'User-Agent' => USER_AGENT) do |response|
            break [response] if response.is_a?(Net::HTTPRedirection)
            raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

            check.call(response)
            break [response, read_body(response, limit)]
          end
        end
        return [response, body, url] unless response.is_a?(Net::HTTPRedirection)
        raise 'too many redirects' if redirects.zero?

        get(URI.join(url, LinkPreviews.ascii_url(response['location'])).to_s, limit, redirects - 1, &check)
      end

      def read_body(response, limit)
        body = +''.b
        response.read_body do |chunk|
          body << chunk
          break if body.bytesize > limit
        end
        body
      end

      def load
        path = File.join(@directory, CACHE_FILE)
        entries = File.exist?(path) ? YAML.safe_load_file(path) || {} : {}
        raise CacheError, "#{CACHE_DIR}/#{CACHE_FILE} must be a mapping of URLs to entries" unless entries.is_a?(Hash)

        entries.each do |url, entry|
          next if entry.is_a?(Hash)

          raise CacheError, "#{CACHE_DIR}/#{CACHE_FILE}: the entry for #{url} must be a mapping with title: and favicon:, " \
                            "not #{entry.inspect}"
        end
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

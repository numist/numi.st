# ABOUTME: Annotates external text links in rendered HTML with popover previews showing the
# ABOUTME: linked page's title and self-hosted favicon, fetched at build time and cached in _link_previews.
require 'jekyll'
require 'net/http'
require 'nokogiri'
require 'cgi'
require 'fileutils'
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

    FAVICON_EXTENSIONS = {
      'image/png' => 'png',
      'image/x-icon' => 'ico',
      'image/vnd.microsoft.icon' => 'ico',
      'image/gif' => 'gif',
      'image/jpeg' => 'jpg',
      'image/webp' => 'webp'
    }.freeze

    # Matches links, plus comments and raw text elements so that links inside them are left alone.
    LINK_PATTERN = %r{<!--.*?-->|<(?<raw>script|style|textarea)\b.*?</\k<raw>\s*>|(?<open><a\s[^>]*>).*?</a\s*>}mi

    def self.external?(href, site_host)
      uri = URI.parse(href.to_s)
      return false unless uri.host && [nil, 'http', 'https'].include?(uri.scheme&.downcase)

      !uri.host.casecmp?(site_host)
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

    def self.annotate(html, site_host, previews)
      html.gsub(LINK_PATTERN) do |match|
        opening_tag = Regexp.last_match[:open]
        link = opening_tag && Nokogiri::HTML5.fragment(match).at_css('a')
        next match unless link && external?(link['href'], site_host) && text_only?(link)

        annotated_opening_tag(link, previews) + match[opening_tag.length..]
      end
    end

    def self.annotated_opening_tag(link, previews)
      href = link['href']
      link['class'] = [link['class'], 'link-preview'].compact.join(' ')
      link['target'] ||= '_blank'
      link['rel'] = (link['rel'].to_s.split | ['noopener']).join(' ')
      link['data-bs-content'] = popover_content(href, previews.title(href) || href, previews.favicon(href))
      attributes = link.attribute_nodes.map { |attribute| %( #{attribute.name}="#{CGI.escapeHTML(attribute.value)}") }
      "<a#{attributes.join}>"
    end

    def self.popover_content(href, title, favicon)
      image = favicon ? %(<img class="link-preview-favicon" src="#{FAVICON_URL_DIR}/#{favicon}" alt="">) : ''
      %(#{image}<a href="#{CGI.escapeHTML(href)}" target="_blank" rel="noopener">#{CGI.escapeHTML(title)}</a>)
    end

    def self.process(site)
      site_host = URI(site.config['url'].to_s).host.to_s
      previews = Previews.new(File.join(site.source, CACHE_DIR))
      (site.pages + site.documents).each do |item|
        next unless item.output && item.output_ext == '.html'

        item.output = annotate(item.output, site_host, previews)
      end
      previews.save
      previews.favicon_files.each { |name| site.static_files << FaviconFile.new(site, name) }
    end

    # Page titles (by URL) and favicons (by host), fetched on demand and cached on disk.
    # Failures are cached as nil so they are not retried on every build.
    class Previews
      def initialize(directory)
        @directory = directory
        @titles = load('titles.yml')
        @favicons = load('favicons.yml')
        @pages = {}
      end

      def title(href)
        url = page_url(href)
        return @titles[url] if @titles.key?(url)

        page = fetch_page(url)
        title = page[:body] && LinkPreviews.extract_title(page[:body], page[:charset])
        Jekyll.logger.warn('Link previews:', "No title found for #{url}") if page[:body] && title.nil?
        @titles[url] = title
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

      def fetch_page(url)
        @pages[url] ||= begin
          response, final_url = get(url)
          raise "not HTML (#{response.content_type})" unless %w[text/html application/xhtml+xml].include?(response.content_type)

          { url: final_url, body: response.body, charset: response.type_params['charset'] }
        rescue StandardError => e
          Jekyll.logger.warn('Link previews:', "Could not fetch #{url}: #{e.message}")
          { url: url }
        end
      end

      def get(url, redirects = MAX_REDIRECTS)
        uri = URI(url)
        options = { use_ssl: uri.scheme == 'https', open_timeout: TIMEOUT, read_timeout: TIMEOUT }
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
          extension = FAVICON_EXTENSIONS[response.content_type]
          next unless extension && !response.body.to_s.empty?

          name = "#{host}.#{extension}"
          FileUtils.mkdir_p(File.join(@directory, 'favicons'))
          File.binwrite(File.join(@directory, 'favicons', name), response.body)
          return name
        rescue StandardError
          next
        end
        Jekyll.logger.warn('Link previews:', "No favicon found for #{host}")
        nil
      end

      def load(name)
        path = File.join(@directory, name)
        File.exist?(path) ? YAML.safe_load_file(path) || {} : {}
      end

      def write(name, data)
        path = File.join(@directory, name)
        yaml = data.sort.to_h.to_yaml
        return if File.exist?(path) && File.binread(path) == yaml.b

        FileUtils.mkdir_p(@directory)
        File.write(path, yaml)
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

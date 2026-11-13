# ABOUTME: Annotates text links in rendered HTML with popover previews of the linked page's title, favicon, and fragment:
# ABOUTME: fetched at build time and cached in _link_previews for other sites, taken from the build for this one.
require 'jekyll'
require 'net/http'
require 'webrick'
require 'nokogiri'
require 'cgi'
require 'digest'
require 'fileutils'
require 'yaml'

module Jekyll
  module LinkPreviews
    CACHE_DIR = '_link_previews'
    CACHE_FILE = 'links.yml'
    FIX_HINT = "set title: and remove error: in #{CACHE_DIR}/#{CACHE_FILE}, or delete the entry to retry"
    FRAGMENT_FIX_HINT = "set its value under fragments: in #{CACHE_DIR}/#{CACHE_FILE}, or delete it to retry"
    FAVICON_URL_DIR = '/assets/img/favicons'
    # The site's own favicon, as _includes/head.html declares it, relative to the baseurl.
    SITE_FAVICON = '/favicon.png'
    USER_AGENT = 'numi.st link preview builder'
    TIMEOUT = 5
    MAX_REDIRECTS = 5
    PAGE_SIZE_LIMIT = 1024 * 1024
    FAVICON_SIZE_LIMIT = 512 * 1024

    # Elements that may appear inside a link without it ceasing to be a text link.
    TEXT_ELEMENTS = %w[abbr b bdi bdo br cite code del dfn em i ins kbd mark q s samp small span strong sub sup time u var wbr].freeze

    # Elements whose text a reader doesn't see.
    HIDDEN_ELEMENTS = %w[head script style noscript template].freeze

    # Elements whose text a reader sees apart from the text around them: blocks, table cells, and line breaks.
    BLOCK_ELEMENTS = %w[
      address article aside blockquote br caption dd details dialog div dl dt fieldset figcaption figure footer form
      h1 h2 h3 h4 h5 h6 header hgroup hr li main nav ol p pre section summary table tbody td tfoot th thead tr ul
    ].freeze

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
    TAG_ATTRIBUTES = %q{(?>\s*(?:[^\s"'<>/=]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s"'>][^\s>]*))?|/))*\s*}

    # Matches the markup that matters for tracking open elements: comments, doctypes and CDATA
    # (all skipped), and start and end tags.
    TOKEN = %r{
      <!--.*?--> |
      (?<unterminated_comment><!--) |
      <!\[CDATA\[.*?\]\]> |
      <![^>]*> |
      <(?<end>/)?(?<name>[a-z][^\s/<>]*)(?<attributes>#{TAG_ATTRIBUTES})> |
      (?<unparseable_tag></?[a-z])
    }mix

    class MarkupError < StandardError; end
    # Raised when hand-written preview data, in links.yml or a link's data-preview-favicon, is invalid.
    class PreviewDataError < StandardError; end
    # Raised when a link to this site can't be parsed or names something the build doesn't publish.
    class BrokenLinkError < StandardError; end

    def self.external?(href)
      uri = URI.parse(ascii_url(href))
      !uri.host.nil? && [nil, 'http', 'https'].include?(uri.scheme&.downcase)
    rescue URI::InvalidURIError
      false
    end

    # Whether a link is to this site without naming its host: a path, relative path, fragment, or query.
    def self.internal?(href)
      !href.nil? && !href.match?(%r{\A(?:[a-z][a-z0-9+.-]*:|//)}i)
    end

    # Percent-encodes non-ASCII characters so that IRIs can be parsed and requested as URIs.
    def self.ascii_url(url)
      url.to_s.gsub(/[^\x00-\x7F]+/) { |characters| characters.bytes.map { |byte| format('%%%02X', byte) }.join }
    end

    def self.text_only?(link)
      !link.text.strip.empty? && link.css('*').all? { |element| TEXT_ELEMENTS.include?(element.name) }
    end

    # Footnote references and back-references, which footnotes.js presents itself.
    def self.footnote?(link)
      (link['class'].to_s.split & %w[footnote reversefootnote]).any?
    end

    def self.not_html_error(content_type)
      "not HTML (#{content_type})"
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

    # Annotates text links inside <article> elements, leaving the rest of the HTML byte-for-byte intact.
    # External links whose href isn't written out in the page's source were generated (e.g. by Liquid),
    # so they aren't fetched or cached. Internal links are annotated when the site's targets are given,
    # with the page's url to resolve them against; links to the page itself are left as they are. Raises
    # MarkupError, naming the page, if the HTML's elements aren't properly closed and nested, and
    # BrokenLinkError if an internal link can't be parsed or its target isn't in the site.
    def self.annotate(html, previews, page: nil, source: nil, targets: nil, url: nil)
      edits = []
      untitled_generated_hrefs = []
      untitled_target_hrefs = []
      missing_fragments = []
      each_element(html, page) do |name, start, opening_tag_end, finish, in_article|
        next unless name == 'a' && in_article

        link = Nokogiri::HTML5.fragment(html[start...finish]).at_css('a')
        next unless link && text_only?(link) && !footnote?(link)

        href = link['href']
        if external?(href)
          generated = !source.nil? && !literal_in_source?(source, href, html[start...opening_tag_end])
          untitled_generated_hrefs << href if generated && squish(link['title']).empty?
          tag = annotated_opening_tag(link, previews, generated: generated, page: page) do |fragment|
            missing_fragments << [href, fragment.description, "; #{FRAGMENT_FIX_HINT}"]
          end
          edits << [start, opening_tag_end, tag]
        elsif targets && internal?(href)
          target = begin
            targets.find(href, url)
          rescue URI::Error
            raise BrokenLinkError, "#{page} links to #{href}, which cannot be parsed as a URL"
          end
          raise BrokenLinkError, "#{page} links to #{href}, which is not in the site" unless target
          next if target.url == targets.find('', url)&.url

          untitled_target_hrefs << href if squish(link['title']).empty? && target.page? && target.title.nil?
          tag = annotated_opening_tag(link, previews, target: target, page: page) do |fragment|
            missing_fragments << [href, fragment.description, '']
          end
          edits << [start, opening_tag_end, tag]
        end
      end
      untitled_generated_hrefs.uniq.each do |href|
        Jekyll.logger.warn('Link preview:', "#{page} links to #{href}, which the page generates; " \
                                            'give the link an inline title, e.g. [text](url "Title") in Markdown, ' \
                                            'or a title attribute in the layout or include that generates it')
      end
      untitled_target_hrefs.uniq.each do |href|
        Jekyll.logger.warn('Link preview:', "#{page} links to #{href}, which has no title; give the page a <title>, " \
                                            'or give the link an inline title, e.g. [text](url "Title") in Markdown')
      end
      missing_fragments.uniq.each do |href, description, hint|
        Jekyll.logger.warn('Link preview:', "#{page} links to #{href}, but #{description} " \
                                            "could not be found on the page it links to#{hint}")
      end
      apply_edits(html, edits)
    end

    # Whether a link's href is written in the page's source as-is or HTML-escaped, rather than generated.
    # The URL must be followed by something that can't continue it, so a generated URL isn't mistaken
    # for a longer literal URL that starts with it.
    def self.literal_in_source?(source, href, opening_tag)
      written = opening_tag.match(/\shref\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))/i)
      [href, written&.captures&.compact&.first].compact.any? do |url|
        source.match?(/#{Regexp.escape(url)}(?=[\s"'<>)\],|;}]|\z)/)
      end
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

    # A link's own title attribute overrides the cached or target page title, and is removed so its
    # native tooltip doesn't compete with the popover. Likewise, its data-preview-favicon names a
    # file in the favicons directory that overrides the cached or site favicon. Links to other sites
    # open in a new tab; links to a target in this site open in the same one. A text fragment's quote
    # follows the title; an element fragment's heading text or id is appended to the linked page's
    # title. Yields the fragment if the linked page doesn't have it.
    def self.annotated_opening_tag(link, previews, generated: false, target: nil, page: nil, &missing)
      href = link['href']
      inline_title = squish(link.remove_attribute('title')&.value)
      inline_favicon = squish(link.remove_attribute('data-preview-favicon')&.value)
      unless inline_favicon.empty?
        favicon = previews.inline_favicon(inline_favicon, [page, "the data-preview-favicon for #{href}"].compact.join(': '))
      end
      title = inline_title unless inline_title.empty?
      if target
        title ||= target.title
      elsif !generated
        title ||= previews.title(href)
        favicon ||= previews.favicon(href)
      end
      fragment = Fragment.parse(href)
      if fragment&.quote?
        quote = find_fragment(fragment, href, previews, generated: generated, target: target, &missing) || fragment.fallback
      elsif fragment && title && inline_title.empty?
        found = find_fragment(fragment, href, previews, generated: generated, target: target, &missing)
        title = "#{title} # #{found || fragment.fallback}"
      end
      link['class'] = [link['class'], 'link-preview'].compact.join(' ')
      unless target
        link['target'] ||= '_blank'
        link['rel'] = (link['rel'].to_s.split | ['noopener']).join(' ')
      end
      favicon_url = favicon ? "#{FAVICON_URL_DIR}/#{favicon}" : target&.favicon_url
      link['data-bs-content'] = popover_content(href, title || href, favicon_url, quote, new_tab: target.nil?)
      link['data-favicon'] = favicon_url if favicon_url
      attributes = link.attribute_nodes.map { |attribute| %( #{attribute.name}="#{CGI.escapeHTML(attribute.value)}") }
      "<a#{attributes.join}>"
    end

    # Returns what fragment names on the page that a link to href links to, or nil if that page isn't
    # searched (it isn't an HTML page in this site, is generated, or its cache entry has an error) or
    # doesn't have it, yielding in the latter case.
    def self.find_fragment(fragment, href, previews, generated:, target:)
      if target
        return unless target.page?

        found = target.fragment_text(fragment)
      else
        return if generated || previews.error?(href)

        found = previews.fragment(href, fragment)
      end
      yield fragment unless found
      found
    end

    def self.popover_content(href, title, favicon_url, quote = nil, new_tab: true)
      image = favicon_url ? %(<img class="link-preview-favicon" src="#{CGI.escapeHTML(favicon_url)}" alt="">) : ''
      new_tab_attributes = new_tab ? ' target="_blank" rel="noopener"' : ''
      blockquote = quote ? %(<blockquote class="link-preview-quote">#{CGI.escapeHTML(quote)}</blockquote>) : ''
      %(#{image}<a href="#{CGI.escapeHTML(href)}"#{new_tab_attributes}>#{CGI.escapeHTML(title)}</a>#{blockquote})
    end

    def self.process(site)
      previews = Previews.new(File.join(site.source, CACHE_DIR))
      targets = Targets.new(site, previews)
      (site.pages + site.documents).each do |item|
        next unless item.output && item.output_ext == '.html'

        source_path = File.join(site.source, item.relative_path)
        source = File.read(source_path) if File.file?(source_path)
        item.output = annotate(item.output, previews, page: item.relative_path, source: source, targets: targets, url: item.url)
      end
      previews.report
      previews.save
      previews.favicon_files.each { |name| site.static_files << FaviconFile.new(site, name) }
    end

    # A page's text as a reader sees it, with blocks and lines separated and runs of whitespace collapsed
    # to a single space.
    def self.visible_text(document)
      text = +''
      append_visible_text(document.root, text) if document.root
      text.gsub(/[[:space:]]+/, ' ').strip
    end

    def self.append_visible_text(node, text)
      return text << node.content if node.is_a?(Nokogiri::XML::Text)
      return unless node.element? && !HIDDEN_ELEMENTS.include?(node.name)

      separated = BLOCK_ELEMENTS.include?(node.name)
      text << ' ' if separated
      node.children.each { |child| append_visible_text(child, text) }
      text << ' ' if separated
    end

    # The part of a link's URL after '#': the id of an element, or a text directive that quotes the
    # page (https://wicg.github.io/scroll-to-text-fragment/), which takes precedence over an id before
    # it. Of several text directives, the first is quoted.
    class Fragment
      HEADINGS = %w[h1 h2 h3 h4 h5 h6].freeze

      # A position that isn't between two characters of a word, in any script.
      WORD_BOUNDARY = '(?:(?<!\p{Word})|(?!\p{Word}))'

      # How the fragment is cached: percent-decoded, with directives keeping the ':~:' that marks them.
      attr_reader :key

      # Returns the fragment of href, or nil if it has none.
      def self.parse(href)
        id, directives = href.to_s[/#(.*)\z/m, 1].to_s.split(':~:', 2)
        text = directives.to_s.split('&').find { |directive| directive.start_with?('text=') }
        terms = text && quote_terms(text.delete_prefix('text='))
        if terms
          new(":~:#{decode(directives)}", **terms)
        elsif !id.to_s.empty?
          new(decode(id), id: decode(id))
        end
      end

      # Splits a text directive's [prefix-,]start[,end][,-suffix] into its percent-decoded terms, or
      # returns nil if it isn't of that form.
      def self.quote_terms(directive)
        parts = directive.split(',', -1)
        prefix = parts.shift.delete_suffix('-') if parts.size > 1 && parts.first.end_with?('-')
        suffix = parts.pop.delete_prefix('-') if parts.size > 1 && parts.last.start_with?('-')
        return unless [1, 2].include?(parts.size) && parts.none?(&:empty?)

        start, finish = parts.map { |part| decode(part) }
        { prefix: prefix && decode(prefix), start: start, finish: finish, suffix: suffix && decode(suffix) }
      end

      def self.decode(text)
        URI::DEFAULT_PARSER.unescape(text).scrub
      end

      def initialize(key, id: nil, prefix: nil, start: nil, finish: nil, suffix: nil)
        @key = key
        @id = id
        @prefix = prefix
        @start = start
        @finish = finish
        @suffix = suffix
      end

      def quote?
        !@start.nil?
      end

      # Returns what the fragment names in a parsed page: the text it quotes, or the text of the heading
      # with its id, or else the id itself. Returns nil if the page has no such text or element.
      def resolve(document)
        quote? ? quote_in(LinkPreviews.visible_text(document)) : element_text(document)
      end

      # What to show when the fragment can't be resolved.
      def fallback
        quote? ? [@start, @finish].compact.join(' … ') : @id
      end

      # What a link names when the fragment can't be resolved, for warnings.
      def description
        quote? ? 'the text it quotes' : "an element with the id #{@id.inspect}"
      end

      private

      def element_text(document)
        element = document.at_xpath('//*[@id=$id]', nil, id: @id) || document.at_xpath('//a[@name=$id]', nil, id: @id)
        return unless element

        HEADINGS.include?(element.name) ? LinkPreviews.squish(element.text) : @id
      end

      # Finds the first start, after the prefix, and the first end after it that the suffix follows,
      # matching whole words case-insensitively, and returns the page's text from the start through the
      # end. Only the first start needs trying: any later start is followed by the same ends or fewer, so
      # the search is a single pass over the text for each.
      def quote_in(text)
        start = text.match(words(@prefix && "#{term(@prefix)} ?", "(?<quote>#{term(@start)})", !@finish && @suffix)) or return
        quote_end = start.end(0)
        if @finish
          finish = text.match(words(nil, term(@finish), @suffix), quote_end) or return
          quote_end = finish.end(0)
        end
        text[start.begin(:quote)...quote_end]
      end

      # Matches the regexp source before and then quote, starting on a word boundary and ending on one,
      # or else followed by the suffix, which ends on one but isn't part of the match.
      def words(before, quote, suffix)
        after = suffix ? "(?= ?#{term(suffix)}#{WORD_BOUNDARY})" : WORD_BOUNDARY
        /#{WORD_BOUNDARY}#{before}#{quote}#{after}/i
      end

      def term(text)
        Regexp.escape(text.gsub(/[[:space:]]+/, ' ').strip)
      end
    end

    # Each linked URL's page title, favicon, and fragments, fetched on demand and cached on disk. Nothing
    # cached is ever refetched, so anything that couldn't be fetched can be filled in by hand.
    class Previews
      def initialize(directory, timeout: TIMEOUT)
        @directory = directory
        @timeout = timeout
        @entries = load
        @pages = {}
        @downloads = {}
        @title_needed = {}
        @inline_favicons = []
      end

      def title(href)
        url = cache_key(href)
        @title_needed[url] = true
        usable_title(entry(url))
      end

      def favicon(href)
        url = cache_key(href)
        @title_needed[url] ||= false
        name = entry(url)['favicon']
        name unless blank?(name)
      end

      # Whether the entry for href has an error, which means the page isn't searched for its fragments.
      def error?(href)
        !blank?(entry(cache_key(href))['error'])
      end

      # Returns what fragment names on the page at href (see Fragment#resolve), or nil if it isn't on the
      # page. A fragment not yet in the entry's fragments is looked for on the page, fetched again if
      # need be, and cached as null if the page doesn't have it or can't be fetched.
      def fragment(href, fragment)
        url = cache_key(href)
        fragments = entry(url)['fragments'] || {}
        unless fragments.key?(fragment.key)
          page = fetch_page(url)
          page[:document] ||= LinkPreviews.parse(page[:body], page[:charset]) if page[:body]
          found = page[:document] && fragment.resolve(page[:document])
          @entries[url]['fragments'] = fragments.merge(fragment.key => found).sort.to_h
        end
        text = @entries[url]['fragments'][fragment.key]
        text unless blank?(text)
      end

      # Returns the name of a favicon that a link names itself, after checking that it exists, so it
      # gets published. owner describes where the name came from, for errors.
      def inline_favicon(name, owner)
        check_favicon(name, owner)
        @inline_favicons << name
        name
      end

      # The title of a file in this site other than a page, which can only be filled in by hand, so its
      # entry starts out with an error.
      def file_title(url, content_type)
        @title_needed[url] = true
        @entries[url] ||= { 'title' => nil, 'error' => LinkPreviews.not_html_error(content_type) }
        usable_title(@entries[url])
      end

      def favicon_files
        (@entries.values.map { |entry| entry['favicon'] }.reject { |name| blank?(name) } + @inline_favicons).uniq
      end

      # Warns once for each URL used in this build whose title was needed but is unusable.
      def report
        @title_needed.each do |url, title_needed|
          entry = @entries[url]
          next unless title_needed && usable_title(entry).nil?

          reason = blank?(entry['error']) ? '' : " (#{entry['error']})"
          Jekyll.logger.warn('Link preview:', "#{url}: no title#{reason}; #{FIX_HINT}")
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

      # An entry's error is about its title: when there is one, the popover shows the URL instead,
      # whatever title the entry has.
      def usable_title(entry)
        title = entry['title']&.to_s
        title unless blank?(title) || !blank?(entry['error'])
      end

      def blank?(value)
        value.to_s.strip.empty?
      end

      def fetch_entry(url)
        page = fetch_page(url)
        title = page[:body] && LinkPreviews.extract_title(page[:body], page[:charset])
        entry = { 'title' => title }
        favicon = discover_favicon(page)
        entry['favicon'] = favicon if favicon
        error = page[:error] || (title ? nil : 'no title found')
        entry['error'] = error if error
        entry
      end

      def fetch_page(url)
        url = LinkPreviews.ascii_url(url)
        @pages[url] ||= begin
          response, body, final_url = get(url, PAGE_SIZE_LIMIT) do |headers|
            %w[text/html application/xhtml+xml].include?(headers.content_type)
          end
          raise LinkPreviews.not_html_error(response.content_type) unless body

          { url: final_url, body: body, charset: response.type_params['charset'] }
        rescue StandardError => e
          { url: url, error: error_message(e) }
        end
      end

      # Returns the file name of the first of the page's candidate favicons that downloads, if any.
      def discover_favicon(page)
        LinkPreviews.icon_urls(page[:body], page[:charset], page[:url]).each do |url|
          @downloads[url] = download_favicon(url) unless @downloads.key?(url)
          return @downloads[url] if @downloads[url]
        end
        nil
      end

      # Returns the downloaded favicon's file name, or nil if there's no usable image at the URL. Favicons
      # are optional, so why one couldn't be used isn't recorded.
      def download_favicon(url)
        response, body, = get(url, FAVICON_SIZE_LIMIT) do |headers|
          !headers.content_type.to_s.match?(%r{\Atext/|svg}) && headers.content_length.to_i <= FAVICON_SIZE_LIMIT
        end
        return nil if body.nil? || body.empty? || body.bytesize > FAVICON_SIZE_LIMIT

        extension = favicon_extension(response.content_type, body)
        return nil unless extension

        name = "#{Digest::SHA256.hexdigest(body)[0, 16]}.#{extension}"
        FileUtils.mkdir_p(File.join(@directory, 'favicons'))
        File.binwrite(favicon_path(name), body) unless File.file?(favicon_path(name))
        name
      rescue StandardError
        nil
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
      # its body, and the final URL. The block decides from the headers whether to read the body; the
      # body is nil for a response it rejects.
      def get(url, limit, redirects = MAX_REDIRECTS, &accept)
        uri = URI(url)
        options = { use_ssl: uri.scheme == 'https', open_timeout: @timeout, read_timeout: @timeout }
        # Breaking out of request_get skips reading the rest of the body; leaving start closes the connection.
        response, body = Net::HTTP.start(uri.host, uri.port, **options) do |http|
          http.request_get(uri.request_uri, 'User-Agent' => USER_AGENT) do |response|
            break [response] if response.is_a?(Net::HTTPRedirection)
            raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

            break [response, accept.call(response) ? read_body(response, limit) : nil]
          end
        end
        return [response, body, url] unless response.is_a?(Net::HTTPRedirection)
        raise 'too many redirects' if redirects.zero?

        get(URI.join(url, LinkPreviews.ascii_url(response['location'])).to_s, limit, redirects - 1, &accept)
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
        raise PreviewDataError, "#{CACHE_DIR}/#{CACHE_FILE} must be a mapping of URLs to entries" unless entries.is_a?(Hash)

        entries.each do |url, entry|
          unless entry.is_a?(Hash)
            raise PreviewDataError, "#{CACHE_DIR}/#{CACHE_FILE}: the entry for #{url} must be a mapping with title: and favicon:, " \
                                    "not #{entry.inspect}"
          end
          check_fragments(entry['fragments'], url)
          name = entry['favicon']
          next if name.is_a?(String) ? blank?(name) : name.nil?

          check_favicon(name, "#{CACHE_DIR}/#{CACHE_FILE}: the favicon for #{url}")
        end
      end

      def check_fragments(fragments, url)
        return if fragments.nil? || (fragments.is_a?(Hash) && fragments.values.all? { |text| text.nil? || text.is_a?(String) })

        raise PreviewDataError, "#{CACHE_DIR}/#{CACHE_FILE}: the fragments for #{url} must be a mapping of fragments to text, " \
                                "not #{fragments.inspect}"
      end

      def check_favicon(name, owner)
        unless name.is_a?(String) && File.basename(name) == name && !name.start_with?('.')
          raise PreviewDataError, "#{owner} must be a file name in #{CACHE_DIR}/favicons/, not #{name.inspect}"
        end
        return if File.file?(favicon_path(name))

        raise PreviewDataError, "#{owner}, #{name}, is not a file in #{CACHE_DIR}/favicons/"
      end
    end

    # The pages and files the build publishes, for resolving internal links to the target they name. A
    # link's path is matched as a browser and web server would: relative to the linking page's URL, after
    # percent-decoding, with a directory's index.html and a page's .html extension optional.
    class Targets
      # A page or file in the build. url is its path, including the baseurl.
      Target = Struct.new(:targets, :url, :item) do
        def page?
          url.end_with?('.html')
        end

        def title
          targets.title(self)
        end

        def favicon_url
          targets.favicon_url
        end

        def fragment_text(fragment)
          targets.fragment_text(self, fragment)
        end
      end

      def initialize(site, previews)
        @previews = previews
        @baseurl = site.baseurl.to_s.chomp('/')
        @items = (site.pages + site.documents + site.static_files).select(&:write?).to_h do |item|
          [item.destination(site.dest).delete_prefix(site.dest), item]
        end
        @titles = {}
        @documents = {}
      end

      # Returns the Target that href, on the page at page_url (excluding the baseurl), names, or nil if it
      # isn't in the build. Raises URI::Error if href can't be parsed.
      def find(href, page_url)
        path = URI.join("http://site#{escape(@baseurl + page_url)}", escape(href)).path
        path = URI::DEFAULT_PARSER.unescape(path)
        return unless path == @baseurl || path.start_with?("#{@baseurl}/")

        path = path.delete_prefix(@baseurl)
        candidates = path.end_with?('/') ? ["#{path}index.html"] : [path, "#{path}/index.html", "#{path}.html"]
        found = candidates.find { |candidate| @items.key?(candidate) }
        Target.new(self, @baseurl + found, @items[found]) if found
      end

      # A page's title comes from its rendered <title>; other files' titles come from the cache.
      def title(target)
        return @previews.file_title(target.url, content_type(target.url)) unless target.page?

        @titles[target.url] = page_title(target.item) unless @titles.key?(target.url)
        @titles[target.url]
      end

      def favicon_url
        @baseurl + SITE_FAVICON
      end

      # Returns what fragment names on a page target (see Fragment#resolve), from the build's output.
      def fragment_text(target, fragment)
        @documents[target.url] ||= LinkPreviews.parse(page_html(target.item), 'UTF-8')
        fragment.resolve(@documents[target.url])
      end

      private

      # Percent-encodes the characters an href may contain that a URI can't.
      def escape(url)
        LinkPreviews.ascii_url(url).gsub(' ', '%20')
      end

      def content_type(url)
        WEBrick::HTTPUtils.mime_type(url, WEBrick::HTTPUtils::DefaultMimeTypes)
      end

      # A rendered page without a title in its front matter has none of its own: its <title> is the site's.
      def page_title(item)
        return if item.respond_to?(:output) && LinkPreviews.squish(item.data['title']).empty?

        LinkPreviews.extract_title(page_html(item), 'UTF-8')
      end

      def page_html(item)
        item.respond_to?(:output) ? item.output : File.read(item.path)
      end
    end

    # Publishes a favicon from _link_previews/favicons at FAVICON_URL_DIR.
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

# ABOUTME: Tests for the link previews plugin: external link detection, HTML annotation,
# ABOUTME: page title and favicon fetching against a local HTTP server, and the on-disk cache.
require 'rspec'
require 'jekyll'
require 'webrick'
require 'tmpdir'
require 'stringio'
require 'logger'
require 'digest'
require_relative '../_plugins/link_previews'

describe Jekyll::LinkPreviews do
  def png_bytes = "\x89PNG\r\n\x1a\nfake png".b
  def ico_bytes = "\x00\x00\x01\x00fake ico".b
  def gif_bytes = "GIF89afake gif".b
  def jpg_bytes = "\xFF\xD8\xFF\xE0fake jpg".b
  def webp_bytes = "RIFF\x10\x00\x00\x00WEBPVP8 fake".b
  def svg_bytes = '<svg xmlns="http://www.w3.org/2000/svg"></svg>'.b

  before(:all) do
    @requests = []
    @server = WEBrick::HTTPServer.new(
      BindAddress: '127.0.0.1', Port: 0,
      Logger: WEBrick::Log.new(StringIO.new), AccessLog: []
    )
    serve = lambda do |path, content_type, body, status = 200, headers = {}|
      @server.mount_proc(path) do |request, response|
        @requests << request.path
        response.status = status
        response['Content-Type'] = content_type
        headers.each { |name, value| response[name] = value }
        response.body = body
      end
    end
    icon_page = ->(href) { %(<html><head><title>Icon</title><link rel="icon" href="#{href}"></head></html>) }
    serve.('/page', 'text/html; charset=utf-8',
           "<html><head><title>\n  Fish &amp; Chips:\n\t&ldquo;A History&rdquo;  </title>" \
           '<link rel="icon" href="/static/icon.png"></head><body></body></html>')
    serve.('/og', 'text/html', '<html><head><meta property="og:title" content="OG &amp; Title"></head></html>')
    serve.('/empty-title', 'text/html',
           '<html><head><title> </title><meta property="og:title" content="From OG"></head></html>')
    serve.('/long-title', 'text/html', "<html><head><title>#{'Long words ' * 12}</title></head></html>")
    serve.('/untitled', 'text/html', '<html><head></head><body>No title here</body></html>')
    serve.('/latin1', 'text/html; charset=iso-8859-1', "<html><head><title>Caf\xE9</title></head></html>".b)
    serve.('/meta-charset', 'text/html',
           "<html><head><meta charset=\"windows-1252\"><title>\x93Quoted\x94</title></head></html>".b)
    serve.('/redirect', 'text/html', '', 302, 'Location' => '/page')
    serve.('/moved', 'text/html', '', 302, 'Location' => '/nested/page')
    serve.('/nested/page', 'text/html', icon_page.('icon.gif'))
    serve.('/nested/icon.gif', 'image/gif', gif_bytes)
    serve.('/redirect-loop', 'text/html', '', 302, 'Location' => '/redirect-loop')
    serve.('/paper.pdf', 'application/pdf', '%PDF-1.4 fake')
    serve.('/missing', 'text/html', '<html><head><title>Not Found</title></head></html>', 404)
    serve.('/static/icon.png', 'image/png', png_bytes)
    serve.('/favicon.ico', 'image/x-icon', ico_bytes)
    { 'ico' => ico_bytes, 'png' => png_bytes, 'gif' => gif_bytes, 'jpg' => jpg_bytes, 'webp' => webp_bytes }
      .each do |extension, bytes|
        serve.("/generic-#{extension}", 'text/html', icon_page.("/static/generic.#{extension}"))
        serve.("/static/generic.#{extension}", 'application/octet-stream', bytes)
      end
    serve.('/svg-icon', 'text/html', icon_page.('/static/icon.svg'))
    serve.('/static/icon.svg', 'image/svg+xml', svg_bytes)
    serve.('/generic-svg', 'text/html', icon_page.('/static/generic.svg'))
    serve.('/static/generic.svg', 'application/octet-stream', svg_bytes)
    serve.('/junk-icon', 'text/html', icon_page.('/static/junk'))
    serve.('/markup-title', 'text/html',
           %(<html><head><title>&lt;img src=x onerror=alert(1)&gt;"'</title></head></html>))
    @server.mount_proc('/slow') do |request, response|
      @requests << request.path
      sleep 0.5
      response.body = '<title>Too Late</title>'
    end
    serve.('/static/junk', 'application/octet-stream', 'not an image')
    @server.mount_proc('/iri') do |request, response|
      @requests << request.unparsed_uri
      response['Content-Type'] = 'text/html'
      response.body = %(<html><head><title>IRI</title><link rel="icon" href="ícone.png"></head></html>)
    end
    @streamed = {}
    stream = lambda do |path, content_type, first_chunk|
      @server.mount_proc(path) do |request, response|
        @requests << request.path
        response['Content-Type'] = content_type
        response.chunked = true
        response.body = proc do |out|
          @streamed[path] = 0
          [first_chunk, *Array.new(1024) { 'x' * 65_536 }].each do |chunk|
            out.write(chunk)
            @streamed[path] += chunk.bytesize
          end
        rescue Errno::EPIPE, Errno::ECONNRESET, IOError
          nil
        end
      end
    end
    stream.('/video.mp4', 'video/mp4', 'fake video')
    stream.('/huge.html', 'text/html', '<html><head><title>Huge</title></head><body>')
    serve.('/huge-icon', 'text/html', icon_page.('/static/huge.png'))
    stream.('/static/huge.png', 'image/png', png_bytes)
    serve.('/big-icon', 'text/html', icon_page.('/static/big.png'))
    serve.('/static/big.png', 'image/png', png_bytes + ('x' * 600_000))
    @thread = Thread.new { @server.start }
    @base = "http://127.0.0.1:#{@server.config[:Port]}"
  end

  after(:all) do
    @server.shutdown
    @thread.join
  end

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      @log = StringIO.new
      original_writer = Jekyll.logger.writer
      Jekyll.logger = Logger.new(@log)
      begin
        @requests.clear
        example.run
      ensure
        Jekyll.logger = original_writer
      end
    end
  end

  def cache_dir
    File.join(@dir, '_link_previews')
  end

  def links_path
    File.join(cache_dir, 'links.yml')
  end

  def favicon_name(bytes, extension)
    "#{Digest::SHA256.hexdigest(bytes)[0, 16]}.#{extension}"
  end

  def unused_port
    TCPServer.open('127.0.0.1', 0) { |server| server.addr[1] }
  end

  describe '.external?' do
    def external?(href)
      described_class.external?(href)
    end

    it 'treats absolute http and https links as external' do
      expect(external?('https://github.com/numist')).to be true
      expect(external?('http://example.com/')).to be true
    end

    it 'treats protocol-relative links as external' do
      expect(external?('//example.com/path')).to be true
    end

    it "treats absolute links to this site's own host as external" do
      expect(external?('https://numi.st/post/2025/airbags/')).to be true
    end

    it 'treats relative paths, fragments, and other schemes as internal' do
      expect(external?('/about/')).to be false
      expect(external?('post/2022/x/')).to be false
      expect(external?('#fn:1')).to be false
      expect(external?('mailto:blog@numist.net')).to be false
      expect(external?('ftp://example.com/file')).to be false
      expect(external?(nil)).to be false
      expect(external?('')).to be false
    end

    it 'treats IRIs with non-ASCII characters as external' do
      expect(external?('https://en.wikipedia.org/wiki/Café')).to be true
    end

    it 'treats unparseable hrefs as internal' do
      expect(external?('https://exa mple.com/%%')).to be false
    end
  end

  describe '.text_only?' do
    def link(html)
      Nokogiri::HTML5.fragment(html).at_css('a')
    end

    it 'accepts links containing only text' do
      expect(described_class.text_only?(link('<a href="x">GitHub</a>'))).to be true
    end

    it 'accepts links containing inline text formatting' do
      expect(described_class.text_only?(link('<a href="x"><code>Data</code> and <em>more</em></a>'))).to be true
    end

    it 'rejects links containing images, svgs, pictures, or video' do
      expect(described_class.text_only?(link('<a href="x"><img src="y"></a>'))).to be false
      expect(described_class.text_only?(link('<a href="x">Text <svg><path d=""/></svg></a>'))).to be false
      expect(described_class.text_only?(link('<a href="x"><picture></picture>Text</a>'))).to be false
      expect(described_class.text_only?(link('<a href="x"><video></video>Text</a>'))).to be false
    end

    it 'rejects links with no text' do
      expect(described_class.text_only?(link('<a href="x"> </a>'))).to be false
    end
  end

  describe '.extract_title' do
    it 'collapses whitespace and decodes entities' do
      html = "<title>\n  Fish &amp; Chips:\n\t&ldquo;A History&rdquo;  </title>"
      expect(described_class.extract_title(html.b, nil)).to eq('Fish & Chips: “A History”')
    end

    it 'falls back to og:title' do
      html = '<html><head><meta property="og:title" content="  OG  Title "></head></html>'
      expect(described_class.extract_title(html.b, nil)).to eq('OG Title')
    end

    it 'returns nil when there is no title' do
      expect(described_class.extract_title('<p>hi</p>'.b, nil)).to be_nil
    end

    it 'respects the charset from the response' do
      expect(described_class.extract_title("<title>Caf\xE9</title>".b, 'iso-8859-1')).to eq('Café')
    end

    it 'respects a meta charset declaration' do
      html = "<meta charset=\"windows-1252\"><title>\x93Quoted\x94</title>".b
      expect(described_class.extract_title(html, nil)).to eq('“Quoted”')
    end

    it 'assumes UTF-8 when no charset is declared' do
      expect(described_class.extract_title('<title>Café — “x”</title>'.b, nil)).to eq('Café — “x”')
    end
  end

  describe '.icon_urls' do
    it 'prefers rel=icon links, then apple-touch-icon, then /favicon.ico' do
      html = '<html><head>' \
             '<link rel="apple-touch-icon" href="/apple.png">' \
             '<link rel="Shortcut Icon" href="img/icon.png">' \
             '<link rel="stylesheet" href="/style.css">' \
             '</head></html>'
      expect(described_class.icon_urls(html.b, nil, 'https://example.com/a/page')).to eq(
        ['https://example.com/a/img/icon.png', 'https://example.com/apple.png', 'https://example.com/favicon.ico']
      )
    end

    it 'falls back to /favicon.ico when the page declares no icon' do
      expect(described_class.icon_urls('<title>x</title>'.b, nil, 'https://example.com/a/b')).to eq(
        ['https://example.com/favicon.ico']
      )
    end

    it 'falls back to /favicon.ico when there is no page' do
      expect(described_class.icon_urls(nil, nil, 'https://example.com/a/b')).to eq(
        ['https://example.com/favicon.ico']
      )
    end

    it 'skips data URIs' do
      html = '<link rel="icon" href="data:image/png;base64,AAAA">'
      expect(described_class.icon_urls(html.b, nil, 'https://example.com/')).to eq(
        ['https://example.com/favicon.ico']
      )
    end
  end

  describe Jekyll::LinkPreviews::Previews do
    subject(:previews) { described_class.new(cache_dir) }

    def report(previews_to_report = previews)
      previews_to_report.report
      @log.string
    end

    def fix_hint
      'set title:/favicon: in _link_previews/links.yml (drop images in _link_previews/favicons/), ' \
        'or delete the entry to retry'
    end

    it 'fetches page titles' do
      expect(previews.title("#{@base}/page")).to eq('Fish & Chips: “A History”')
      expect(previews.title("#{@base}/og")).to eq('OG & Title')
      expect(previews.title("#{@base}/empty-title")).to eq('From OG')
      expect(previews.title("#{@base}/latin1")).to eq('Café')
      expect(previews.title("#{@base}/meta-charset")).to eq('“Quoted”')
      expect(report).to be_empty
    end

    it 'follows redirects' do
      expect(previews.title("#{@base}/redirect")).to eq('Fish & Chips: “A History”')
    end

    it 'ignores the fragment when fetching' do
      expect(previews.title("#{@base}/page#section")).to eq('Fish & Chips: “A History”')
      expect(previews.title("#{@base}/page")).to eq('Fish & Chips: “A History”')
      expect(@requests).to eq(['/page', '/static/icon.png'])
    end

    {
      '/untitled' => 'no title found',
      '/paper.pdf' => 'not HTML (application/pdf)',
      '/missing' => 'HTTP 404',
      '/redirect-loop' => 'too many redirects'
    }.each do |path, reason|
      it "returns nil and explains how to fix a missing title (#{reason})" do
        expect(previews.title("#{@base}#{path}")).to be_nil
        expect(report).to include("Link preview: #{@base}#{path}: no title (title: #{reason}); #{fix_hint}")
      end
    end

    it 'stops following redirects after five' do
      previews.title("#{@base}/redirect-loop")
      expect(@requests.count('/redirect-loop')).to eq(6)
    end

    it 'records why both the title and favicon are missing for unreachable hosts' do
      url = "http://127.0.0.1:#{unused_port}/"
      expect(previews.title(url)).to be_nil
      expect(previews.favicon(url)).to be_nil
      expect(report).to match(
        %r{Link preview: #{Regexp.escape(url)}: no title, no favicon \(title: Failed to open TCP connection to [^;]+; favicon: Failed to open TCP connection to [^;]+\); #{Regexp.escape(fix_hint)}}
      )
    end

    it 'gives up on pages that respond too slowly, recording a clean error' do
      slow = described_class.new(cache_dir, timeout: 0.1)
      expect(slow.title("#{@base}/slow")).to be_nil
      slow.save
      expect(YAML.load_file(links_path).fetch("#{@base}/slow")).to eq(
        'title' => nil, 'favicon' => favicon_name(ico_bytes, 'ico'), 'error' => 'title: Net::ReadTimeout'
      )
      expect(report(slow)).to include("Link preview: #{@base}/slow: no title (title: Net::ReadTimeout); #{fix_hint}")
    end

    it 'fetches IRIs percent-encoded, caching them under the href as written' do
      expect(previews.title("#{@base}/iri/café")).to eq('IRI')
      previews.save
      expect(@requests).to eq(['/iri/caf%C3%A9', '/iri/%C3%ADcone.png', '/favicon.ico'])
      expect(YAML.load_file(links_path).keys).to eq(["#{@base}/iri/café"])
    end

    describe 'large responses' do
      def streamed_megabytes(path)
        @streamed.fetch(path) / 1_048_576.0
      end

      it 'does not download the body of a non-HTML link' do
        expect(previews.title("#{@base}/video.mp4")).to be_nil
        previews.save
        expect(YAML.load_file(links_path).fetch("#{@base}/video.mp4")['error']).to start_with('title: not HTML (video/mp4)')
        expect(streamed_megabytes('/video.mp4')).to be < 16
      end

      it 'reads only the start of a huge page' do
        expect(previews.title("#{@base}/huge.html")).to eq('Huge')
        expect(streamed_megabytes('/huge.html')).to be < 16
      end

      it 'rejects favicons that are too large, whether or not their size is declared' do
        expect(previews.favicon("#{@base}/big-icon")).to eq(favicon_name(ico_bytes, 'ico'))
        expect(previews.favicon("#{@base}/huge-icon")).to eq(favicon_name(ico_bytes, 'ico'))
        expect(streamed_megabytes('/static/huge.png')).to be < 16
      end
    end

    it 'caches protocol-relative links under their https URL' do
      href = "//127.0.0.1:#{@server.config[:Port]}/page"
      previews.title(href)
      previews.save
      expect(YAML.load_file(links_path).keys).to eq(["https:#{href}"])
      expect(report).to include("Link preview: https:#{href}: no title, no favicon (")
    end

    it 'warns once per URL per build, covering everything missing' do
      3.times do
        previews.title("#{@base}/missing")
        previews.favicon("#{@base}/missing")
      end
      expect(report.scan('Link preview:').size).to eq(1)
    end

    it 'only warns about a missing title when the title was needed' do
      previews.favicon("#{@base}/missing")
      expect(report).to be_empty
    end

    describe 'favicons' do
      it "downloads the favicon declared by the page, named by its content" do
        expect(previews.favicon("#{@base}/page")).to eq(favicon_name(png_bytes, 'png'))
        expect(File.binread(File.join(cache_dir, 'favicons', favicon_name(png_bytes, 'png')))).to eq(png_bytes)
      end

      it 'falls back to /favicon.ico' do
        expect(previews.favicon("#{@base}/untitled")).to eq(favicon_name(ico_bytes, 'ico'))
        expect(File.binread(File.join(cache_dir, 'favicons', favicon_name(ico_bytes, 'ico')))).to eq(ico_bytes)
      end

      it 'discovers a favicon for each URL, resolving it against the final URL after redirects' do
        expect(previews.favicon("#{@base}/moved")).to eq(favicon_name(gif_bytes, 'gif'))
        expect(previews.favicon("#{@base}/page")).to eq(favicon_name(png_bytes, 'png'))
        expect(@requests).to eq(['/moved', '/nested/page', '/nested/icon.gif', '/page', '/static/icon.png'])
      end

      it 'downloads each favicon URL once per build' do
        previews.favicon("#{@base}/untitled")
        previews.favicon("#{@base}/og")
        expect(@requests.count('/favicon.ico')).to eq(1)
      end

      it 'stores identical favicons once' do
        expect(previews.favicon("#{@base}/generic-png")).to eq(previews.favicon("#{@base}/page"))
        expect(Dir.children(File.join(cache_dir, 'favicons'))).to eq([favicon_name(png_bytes, 'png')])
      end

      %w[ico png gif jpg webp].each do |extension|
        it "recognizes #{extension} favicons served with a generic content type" do
          bytes = send("#{extension}_bytes")
          expect(previews.favicon("#{@base}/generic-#{extension}")).to eq(favicon_name(bytes, extension))
          expect(@requests).to eq(["/generic-#{extension}", "/static/generic.#{extension}"])
        end
      end

      it 'rejects SVG favicons whatever their content type' do
        expect(previews.favicon("#{@base}/svg-icon")).to eq(favicon_name(ico_bytes, 'ico'))
        expect(previews.favicon("#{@base}/generic-svg")).to eq(favicon_name(ico_bytes, 'ico'))
      end

      it 'rejects favicons that are not recognizable images' do
        expect(previews.favicon("#{@base}/junk-icon")).to eq(favicon_name(ico_bytes, 'ico'))
      end

      it 'fetches each page only once when asked for both its title and favicon' do
        previews.title("#{@base}/page")
        previews.favicon("#{@base}/page")
        expect(@requests).to eq(['/page', '/static/icon.png'])
      end

      it 'lists the favicon files that cache entries name' do
        previews.favicon("#{@base}/page")
        previews.favicon("#{@base}/untitled")
        expect(previews.favicon_files).to contain_exactly(favicon_name(png_bytes, 'png'), favicon_name(ico_bytes, 'ico'))
      end
    end

    describe 'caching' do
      def write_links(yaml)
        FileUtils.mkdir_p(File.join(cache_dir, 'favicons'))
        File.write(links_path, yaml)
      end

      it 'writes one hand-editable entry per URL, sorted' do
        previews.title("#{@base}/page")
        previews.title("#{@base}/missing")
        previews.save
        expect(File.read(links_path)).to eq(<<~YAML)
          ---
          #{@base}/missing:
            title:
            favicon: #{favicon_name(ico_bytes, 'ico')}
            error: 'title: HTTP 404'
          #{@base}/page:
            title: 'Fish & Chips: “A History”'
            favicon: #{favicon_name(png_bytes, 'png')}
        YAML
      end

      it 'keeps long titles on one line' do
        previews.title("#{@base}/long-title")
        previews.save
        expect(File.read(links_path)).to include("  title: #{('Long words ' * 12).strip}\n")
      end

      it 'persists entries so a later build makes no requests' do
        previews.title("#{@base}/page")
        previews.save
        @requests.clear

        cached = described_class.new(cache_dir)
        expect(cached.title("#{@base}/page")).to eq('Fish & Chips: “A History”')
        expect(cached.favicon("#{@base}/page")).to eq(favicon_name(png_bytes, 'png'))
        expect(@requests).to be_empty
      end

      it 'never refetches failures, but warns about them on every build' do
        previews.title("#{@base}/missing")
        previews.save
        @requests.clear

        cached = described_class.new(cache_dir)
        expect(cached.title("#{@base}/missing")).to be_nil
        expect(@requests).to be_empty
        expect(report(cached)).to include("Link preview: #{@base}/missing: no title (title: HTTP 404); #{fix_hint}")
      end

      it 'uses hand-filled titles and favicons without fetching or warning' do
        write_links(<<~YAML)
          #{@base}/missing:
            title: Filled In By Hand
            favicon: by-hand.png
            error: 'title: HTTP 404'
        YAML
        File.binwrite(File.join(cache_dir, 'favicons', 'by-hand.png'), png_bytes)
        expect(previews.title("#{@base}/missing")).to eq('Filled In By Hand')
        expect(previews.favicon("#{@base}/missing")).to eq('by-hand.png')
        expect(previews.favicon_files).to eq(['by-hand.png'])
        expect(@requests).to be_empty
        expect(report).to be_empty
      end

      it 'fails on entries that are not mappings' do
        write_links("#{@base}/page: Some Title\n")
        expect { previews }.to raise_error(
          Jekyll::LinkPreviews::CacheError,
          %(_link_previews/links.yml: the entry for #{@base}/page must be a mapping with title: and favicon:, not "Some Title")
        )
      end

      it 'fails on a cache file that is not a mapping' do
        write_links("- #{@base}/page\n")
        expect { previews }.to raise_error(
          Jekyll::LinkPreviews::CacheError, '_link_previews/links.yml must be a mapping of URLs to entries'
        )
      end

      it 'warns when an entry names a favicon file that does not exist' do
        write_links("#{@base}/page:\n  title: Page\n  favicon: gone.png\n")
        expect(previews.favicon("#{@base}/page")).to be_nil
        expect(previews.favicon_files).to be_empty
        expect(report).to include(
          "Link preview: #{@base}/page: favicon gone.png not found in _link_previews/favicons/; #{fix_hint}"
        )
      end

      it 'does not rewrite the cache file when nothing changed' do
        previews.title("#{@base}/page")
        previews.save
        past = Time.now - 3600
        File.utime(past, past, links_path)

        cached = described_class.new(cache_dir)
        cached.title("#{@base}/page")
        cached.save
        expect(File.mtime(links_path).to_i).to eq(past.to_i)
      end

      it 'does not reformat a hand-edited cache file when nothing changed' do
        hand_written = "#{@base}/missing:\n  error: HTTP 404\n  favicon:\n  title: \"By Hand\"\n"
        write_links(hand_written)
        previews.title("#{@base}/missing")
        previews.save
        expect(File.read(links_path)).to eq(hand_written)
      end
    end
  end

  describe '.annotate' do
    let(:previews) { Jekyll::LinkPreviews::Previews.new(cache_dir) }

    def annotate(html)
      described_class.annotate(html, previews)
    end

    def article(html)
      %(<article class="post">#{html}</article>)
    end

    it 'annotates external text links with a popover, a new tab target, and noopener' do
      output = annotate(article(%(<p>See <a href="#{@base}/page">this</a>.</p>)))
      expect(output).to eq(article(
        %(<p>See <a href="#{@base}/page" class="link-preview" target="_blank" rel="noopener" ) +
        %(data-bs-content="&lt;img class=&quot;link-preview-favicon&quot; src=&quot;/assets/img/favicons/#{favicon_name(png_bytes, 'png')}&quot; alt=&quot;&quot;&gt;) +
        %(&lt;a href=&quot;#{@base}/page&quot; target=&quot;_blank&quot; rel=&quot;noopener&quot;&gt;) +
        %(Fish &amp;amp; Chips: “A History”&lt;/a&gt;" data-favicon="/assets/img/favicons/#{favicon_name(png_bytes, 'png')}">this</a>.</p>)
      ))
    end

    it 'gives links with a favicon its URL, for previews built from copies of the link' do
      output = annotate(article(%(<a href="#{@base}/page">with</a><a href="http://127.0.0.1:#{unused_port}/">without</a>)))
      previews.report
      expect(output.scan(/ data-favicon="([^"]*)"/)).to eq([["/assets/img/favicons/#{favicon_name(png_bytes, 'png')}"]])
    end

    it 'falls back to the URL as the title and omits a missing favicon' do
      url = "http://127.0.0.1:#{unused_port}/gone"
      output = annotate(article(%(<a href="#{url}">gone</a>)))
      expect(output).to eq(article(
        %(<a href="#{url}" class="link-preview" target="_blank" rel="noopener" ) +
        %(data-bs-content="&lt;a href=&quot;#{url}&quot; target=&quot;_blank&quot; rel=&quot;noopener&quot;&gt;#{url}&lt;/a&gt;">gone</a>)
      ))
      previews.report
      expect(@log.string).to include("Link preview: #{url}: no title, no favicon (")
    end

    it 'uses a title attribute as the popover title, without caching it or warning about the page title' do
      output = annotate(article(%(<a href="#{@base}/missing" title="  Inline &amp;  Title ">x</a>)))
      previews.report
      previews.save
      expect(output).to eq(article(
        %(<a href="#{@base}/missing" class="link-preview" target="_blank" rel="noopener" ) +
        %(data-bs-content="&lt;img class=&quot;link-preview-favicon&quot; src=&quot;/assets/img/favicons/#{favicon_name(ico_bytes, 'ico')}&quot; alt=&quot;&quot;&gt;) +
        %(&lt;a href=&quot;#{@base}/missing&quot; target=&quot;_blank&quot; rel=&quot;noopener&quot;&gt;) +
        %(Inline &amp;amp; Title&lt;/a&gt;" data-favicon="/assets/img/favicons/#{favicon_name(ico_bytes, 'ico')}">x</a>)
      ))
      expect(@log.string).to be_empty
      expect(YAML.load_file(links_path).fetch("#{@base}/missing")['title']).to be_nil
    end

    describe 'escaping' do
      let(:markup) { %(<img src=x onerror=alert(1)>"') }
      let(:escaped_markup_in_attribute) { '&amp;lt;img src=x onerror=alert(1)&amp;gt;&amp;quot;&amp;#39;' }

      it 'escapes markup in fetched titles' do
        output = annotate(article(%(<a href="#{@base}/markup-title">x</a>)))
        expect(output).to include(%(rel=&quot;noopener&quot;&gt;#{escaped_markup_in_attribute}&lt;/a&gt;"))
        expect(output).not_to include('<img')
      end

      it 'escapes favicon file names' do
        FileUtils.mkdir_p(File.join(cache_dir, 'favicons'))
        File.binwrite(File.join(cache_dir, 'favicons', 'a"b&c.png'), png_bytes)
        File.write(links_path, { "#{@base}/page" => { 'title' => 'Page', 'favicon' => 'a"b&c.png' } }.to_yaml)
        output = annotate(article(%(<a href="#{@base}/page">x</a>)))
        expect(output).to include('src=&quot;/assets/img/favicons/a&amp;quot;b&amp;amp;c.png&quot;')
      end

      it 'escapes markup in inline titles' do
        output = annotate(article(%(<a href="#{@base}/page" title="#{CGI.escapeHTML(markup)}">x</a>)))
        expect(output).to include(%(rel=&quot;noopener&quot;&gt;#{escaped_markup_in_attribute}&lt;/a&gt;"))
        expect(output).not_to include('<img')
      end
    end

    describe 'scanning' do
      def annotated_links(output)
        output.scan(/<a [^>]*class="link-preview"/).size
      end

      it 'handles > inside quoted link attributes' do
        output = annotate(article(%(<a href="#{@base}/page" title="a > b" data-x='c > d'>text</a>)))
        expect(output).to match(%r{\A<article class="post"><a href="#{@base}/page" data-x="c &gt; d" class="link-preview" target="_blank" rel="noopener" data-bs-content="[^"]*" data-favicon="[^"]*">text</a></article>\z})
        expect(output).to include('a &amp;gt; b')
      end

      it 'handles > inside quoted article attributes' do
        output = annotate(%(<article data-x="a > b"><a href="#{@base}/page">in</a></article>))
        expect(annotated_links(output)).to eq(1)
      end

      it 'recognizes uppercase tags' do
        output = annotate(%(<ARTICLE><A HREF="#{@base}/page">in</A></ARTICLE><A HREF="#{@base}/page">out</A>))
        expect(annotated_links(output)).to eq(1)
        expect(output).to end_with(%(<A HREF="#{@base}/page">out</A>))
      end

      it 'tracks nested articles' do
        output = annotate(
          %(<article><article><a href="#{@base}/page">inner</a></article>) +
          %(<a href="#{@base}/page">outer</a></article><a href="#{@base}/page">outside</a>)
        )
        expect(annotated_links(output)).to eq(2)
        expect(output).to end_with(%(</article><a href="#{@base}/page">outside</a>))
      end

      it 'skips links inside style and textarea elements' do
        html = article(
          %(<style>/* <a href="#{@base}/page">styled</a> */</style>) +
          %(<textarea><a href="#{@base}/page">typed</a></textarea>)
        )
        expect(annotate(html)).to eq(html)
        expect(@requests).to be_empty
      end

      it 'skips comments, doctypes, and CDATA' do
        html = %(<!DOCTYPE html><!-- <div> --><svg><![CDATA[ <div> ]]></svg>) +
               article(%(<a href="#{@base}/page">in</a>))
        expect(annotated_links(annotate(html))).to eq(1)
      end

      it 'handles comment markers inside quoted attributes' do
        output = annotate(article(
          %(<a href="#{@base}/page" data-x="<!--">one</a><a href="#{@base}/og">two</a><!-- -->)
        ))
        expect(annotated_links(output)).to eq(2)
      end

      it 'accepts void and self-closing elements' do
        html = article(%(<p>a<br>b<img src="x"><wbr><input><hr><svg><path d="M0"/></svg><br /></p>))
        expect(annotate(html)).to eq(html)
      end

      it 'matches tag names case-insensitively' do
        html = %(<DIV><p>x</P></div>)
        expect(annotate(html)).to eq(html)
      end
    end

    describe 'unbalanced markup' do
      def annotate_page(html)
        described_class.annotate(html, Jekyll::LinkPreviews::Previews.new(cache_dir), page: 'notes/page.md')
      end

      def markup_error
        Jekyll::LinkPreviews::MarkupError
      end

      it 'fails on an unclosed element' do
        expect { annotate_page(%(<div>\n<section>\n</div>)) }.to raise_error(
          markup_error, 'notes/page.md:3: </div> does not close <section> from line 2'
        )
      end

      it 'fails on an element still open at the end' do
        expect { annotate_page(%(<div>\n<p>text\n</div>)) }.to raise_error(
          markup_error, 'notes/page.md:3: </div> does not close <p> from line 2'
        )
        expect { annotate_page(%(<div>\n<div>\n</div>)) }.to raise_error(
          markup_error, 'notes/page.md:1: <div> is never closed'
        )
      end

      it 'fails on a stray end tag' do
        expect { annotate_page(%(<p>x</p>\n</div>)) }.to raise_error(markup_error, 'notes/page.md:2: stray </div>')
      end

      it 'does not infer optional end tags' do
        expect { annotate_page(%(<ul><li>one<li>two</ul>)) }.to raise_error(markup_error, /does not close <li>/)
        expect { annotate_page(%(<p>one<p>two)) }.to raise_error(markup_error, /<p> is never closed/)
      end

      it 'fails on an unclosed link' do
        expect do
          annotate_page(
            %(<article><a href="#{@base}/page">unclosed</article>) +
            %(<footer><a href="#{@base}/page">footer</a></footer>)
          )
        end.to raise_error(markup_error, 'notes/page.md:1: </article> does not close <a> from line 1')
        expect(@requests).to be_empty
      end

      it 'fails on a link inside a link' do
        expect { annotate_page(%(<a href="#{@base}/page">o\n<a href="#{@base}/og">i</a></a>)) }.to raise_error(
          markup_error, 'notes/page.md:2: <a> inside <a> from line 1'
        )
      end

      it 'fails on unterminated comments and raw text elements' do
        expect { annotate_page(%(<p>\n<!-- x</p>)) }.to raise_error(markup_error, 'notes/page.md:2: unterminated comment')
        expect { annotate_page(%(<script>x)) }.to raise_error(markup_error, 'notes/page.md:1: <script> is never closed')
      end
    end

    it 'preserves existing attributes, classes, targets, and rel values' do
      output = annotate(article(%(<a class="u-url" href="#{@base}/page" target="_self" rel="me">x</a>)))
      expect(output).to start_with(
        %(<article class="post"><a class="u-url link-preview" href="#{@base}/page" target="_self" rel="me noopener" data-bs-content=")
      )
    end

    it 'annotates links containing inline formatting without touching their content' do
      output = annotate(article(%(<a href="#{@base}/page"><code>&lt;T&gt;</code> &rsquo;s</a>)))
      expect(output).to end_with(%("><code>&lt;T&gt;</code> &rsquo;s</a></article>))
      expect(output).to include('class="link-preview"')
    end

    it 'leaves internal links, icon links, comments, and scripts untouched' do
      html = article(<<~HTML)
        <a href="/about/">about</a>
        <a href="mailto:blog@numist.net">email</a>
        <a href="#{@base}/page"><svg class="social-svg-icon"><use xlink:href="#github"></use></svg></a>
        <!-- <a href="#{@base}/page">commented</a> -->
        <script>var s = '<a href="#{@base}/page">scripted</a>';</script>
        <pre><code>  indented &amp; spaced  </code></pre>
      HTML
      expect(annotate(html)).to eq(html)
      expect(@requests).to be_empty
    end

    it 'leaves links outside articles untouched' do
      html = <<~HTML
        <!DOCTYPE html>
        <header><a href="#{@base}/page">header</a></header>
        <!-- <article> -->
        <script>document.write('<article>')</script>
        <footer><a href="#{@base}/page">footer</a></footer>
      HTML
      expect(annotate(html)).to eq(html)
      expect(@requests).to be_empty
    end

    it 'annotates only the links inside articles' do
      output = annotate(
        %(<a href="#{@base}/page">before</a>) +
        article(%(<a href="#{@base}/page">one</a>)) +
        %(<a href="#{@base}/page">between</a>) +
        article(%(<a href="#{@base}/og">two</a>)) +
        %(<a href="#{@base}/page">after</a>)
      )
      expect(output.scan('class="link-preview"').size).to eq(2)
      expect(output).to include(%(<a href="#{@base}/page">before</a>))
      expect(output).to include(%(<a href="#{@base}/page">between</a>))
      expect(output).to include(%(<a href="#{@base}/page">after</a>))
      expect(output).to include('OG &amp;amp; Title')
    end
  end

  describe 'site integration' do
    before do
      @source = File.join(@dir, 'source')
      FileUtils.mkdir_p(@source)
      File.write(File.join(@source, 'index.html'), <<~HTML)
        ---
        ---
        <article><a href="#{@base}/page">external</a></article>
        <footer><a href="#{@base}/og">footer</a></footer>
      HTML
      File.write(File.join(@source, 'feed.xml'), <<~XML)
        ---
        ---
        <feed><article><a href="#{@base}/page">external</a></article></feed>
      XML
    end

    def build
      config = Jekyll.configuration(
        'source' => @source, 'destination' => File.join(@dir, '_site'),
        'url' => 'http://example.com', 'quiet' => true
      )
      Jekyll::Site.new(config).process
    end

    it 'fails the build on unbalanced markup, naming the page' do
      File.write(File.join(@source, 'broken.html'), "---\n---\n<div>\n")
      expect { build }.to raise_error(Jekyll::LinkPreviews::MarkupError, 'broken.html:1: <div> is never closed')
    end

    describe 'generated links' do
      before do
        FileUtils.mkdir_p(File.join(@source, '_layouts'))
        File.write(File.join(@source, '_layouts/post.html'), "<article>{{ content }}</article>\n")
        File.write(File.join(@source, 'post.md'), <<~MARKDOWN)
          ---
          layout: post
          ---
          An [inline link](#{@base}/page?a=1&b=2), a [reference link][ref], an autolink <#{@base}/latin1>,
          <a href="#{@base}/meta-charset?x=1&amp;y=2">raw HTML</a>,
          a [generated link]({{ site.generated }}/empty-title),
          and a [titled generated link]({{ site.generated }}/untitled "Titled By Hand").

          [ref]: #{@base}/og
        MARKDOWN
      end

      def build_post
        config = Jekyll.configuration(
          'source' => @source, 'destination' => File.join(@dir, '_site'),
          'url' => 'http://example.com', 'generated' => @base
        )
        Jekyll::Site.new(config).process
        File.read(File.join(@dir, '_site/post.html'))
      end

      it 'previews literal links from the source' do
        output = build_post
        expect(output.scan('class="link-preview"').size).to eq(6)
        expect(YAML.load_file(File.join(@source, '_link_previews/links.yml')).keys).to contain_exactly(
          "#{@base}/page?a=1&b=2", "#{@base}/og", "#{@base}/latin1", "#{@base}/meta-charset?x=1&y=2",
          "#{@base}/page" # from index.html
        )
      end

      it 'does not fetch or cache links built by the page' do
        build_post
        expect(@requests).not_to include('/empty-title', '/untitled')
      end

      it 'shows the URL without a favicon and warns on every build when a generated link has no title' do
        2.times { build_post }
        expect(@log.string.scan(
          "Link preview: post.md links to #{@base}/empty-title, which the page generates; " \
          'give the link an inline title, e.g. [text](url "Title")'
        ).size).to eq(2)
        expect(build_post).to include(
          %(data-bs-content="&lt;a href=&quot;#{@base}/empty-title&quot; target=&quot;_blank&quot; rel=&quot;noopener&quot;&gt;#{@base}/empty-title&lt;/a&gt;")
        )
      end

      it 'uses the inline title of a generated link without a favicon' do
        expect(build_post).to include(
          %(data-bs-content="&lt;a href=&quot;#{@base}/untitled&quot; target=&quot;_blank&quot; rel=&quot;noopener&quot;&gt;Titled By Hand&lt;/a&gt;")
        )
        expect(@log.string).not_to include('/untitled')
      end
    end

    it 'annotates HTML pages, leaves other outputs alone, and publishes favicons' do
      build
      site = File.join(@dir, '_site')
      index = File.read(File.join(site, 'index.html'))
      expect(index).to include(%(<a href="#{@base}/page" class="link-preview" target="_blank" rel="noopener" data-bs-content="))
      expect(index).to include(%(<footer><a href="#{@base}/og">footer</a></footer>))
      expect(File.read(File.join(site, 'feed.xml'))).to eq(
        %(<feed><article><a href="#{@base}/page">external</a></article></feed>\n)
      )
      expect(File.binread(File.join(site, 'assets/img/favicons', favicon_name(png_bytes, 'png')))).to eq(png_bytes)
      expect(YAML.load_file(File.join(@source, '_link_previews/links.yml'))).to eq(
        "#{@base}/page" => { 'title' => 'Fish & Chips: “A History”', 'favicon' => favicon_name(png_bytes, 'png') }
      )
    end

    it 'keeps favicons published on rebuilds' do
      build
      @requests.clear
      build
      expect(@requests).to be_empty
      expect(File.exist?(File.join(@dir, '_site/assets/img/favicons', favicon_name(png_bytes, 'png')))).to be true
    end
  end
end

# ABOUTME: Tests for the link previews plugin: external link detection, HTML annotation,
# ABOUTME: page title and favicon fetching against a local HTTP server, and the on-disk cache.
require 'rspec'
require 'jekyll'
require 'webrick'
require 'tmpdir'
require 'stringio'
require 'logger'
require_relative '../_plugins/link_previews'

describe Jekyll::LinkPreviews do
  PNG_BYTES = "\x89PNG\r\n\x1a\nfake png".b
  ICO_BYTES = "\x00\x00\x01\x00fake ico".b

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
    serve.('/page', 'text/html; charset=utf-8',
           "<html><head><title>\n  Fish &amp; Chips:\n\t&ldquo;A History&rdquo;  </title>" \
           '<link rel="icon" href="/static/icon.png"></head><body></body></html>')
    serve.('/og', 'text/html', '<html><head><meta property="og:title" content="OG &amp; Title"></head></html>')
    serve.('/empty-title', 'text/html',
           '<html><head><title> </title><meta property="og:title" content="From OG"></head></html>')
    serve.('/untitled', 'text/html', '<html><head></head><body>No title here</body></html>')
    serve.('/latin1', 'text/html; charset=iso-8859-1', "<html><head><title>Caf\xE9</title></head></html>".b)
    serve.('/meta-charset', 'text/html',
           "<html><head><meta charset=\"windows-1252\"><title>\x93Quoted\x94</title></head></html>".b)
    serve.('/redirect', 'text/html', '', 302, 'Location' => '/page')
    serve.('/redirect-loop', 'text/html', '', 302, 'Location' => '/redirect-loop')
    serve.('/paper.pdf', 'application/pdf', '%PDF-1.4 fake')
    serve.('/missing', 'text/html', '<html><head><title>Not Found</title></head></html>', 404)
    serve.('/static/icon.png', 'image/png', PNG_BYTES)
    serve.('/favicon.ico', 'image/x-icon', ICO_BYTES)
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
      original_logger = Jekyll.logger
      Jekyll.instance_variable_set(:@logger, Jekyll::LogAdapter.new(Logger.new(@log), :info))
      begin
        @requests.clear
        example.run
      ensure
        Jekyll.instance_variable_set(:@logger, original_logger)
      end
    end
  end

  def cache_dir
    File.join(@dir, '_link_previews')
  end

  describe '.external?' do
    def external?(href)
      described_class.external?(href, 'numi.st')
    end

    it 'treats absolute http and https links to other hosts as external' do
      expect(external?('https://github.com/numist')).to be true
      expect(external?('http://example.com/')).to be true
    end

    it 'treats protocol-relative links to other hosts as external' do
      expect(external?('//example.com/path')).to be true
    end

    it 'treats absolute links to the site host as internal' do
      expect(external?('https://numi.st/post/2025/airbags/')).to be false
      expect(external?('http://NUMI.ST/')).to be false
      expect(external?('//numi.st/feed.xml')).to be false
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

    it 'treats unparseable hrefs as internal' do
      expect(external?('https://exa mple.com/%%')).to be false
    end

    it 'compares against a site host that includes a port' do
      expect(described_class.external?('http://100.91.17.95:4000/post/', '100.91.17.95')).to be false
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

    it 'fetches page titles' do
      expect(previews.title("#{@base}/page")).to eq('Fish & Chips: “A History”')
      expect(previews.title("#{@base}/og")).to eq('OG & Title')
      expect(previews.title("#{@base}/empty-title")).to eq('From OG')
      expect(previews.title("#{@base}/latin1")).to eq('Café')
      expect(previews.title("#{@base}/meta-charset")).to eq('“Quoted”')
    end

    it 'follows redirects' do
      expect(previews.title("#{@base}/redirect")).to eq('Fish & Chips: “A History”')
    end

    it 'ignores the fragment when fetching' do
      expect(previews.title("#{@base}/page#section")).to eq('Fish & Chips: “A History”')
      expect(previews.title("#{@base}/page")).to eq('Fish & Chips: “A History”')
      expect(@requests).to eq(['/page'])
    end

    it 'returns nil and warns for pages without a title' do
      expect(previews.title("#{@base}/untitled")).to be_nil
      expect(@log.string).to include("Link previews: No title found for #{@base}/untitled")
    end

    it 'returns nil and warns for non-HTML responses' do
      expect(previews.title("#{@base}/paper.pdf")).to be_nil
      expect(@log.string).to include("Link previews: Could not fetch #{@base}/paper.pdf: not HTML (application/pdf)")
    end

    it 'returns nil and warns for HTTP errors' do
      expect(previews.title("#{@base}/missing")).to be_nil
      expect(@log.string).to include("Link previews: Could not fetch #{@base}/missing: HTTP 404")
    end

    it 'returns nil and warns for redirect loops' do
      expect(previews.title("#{@base}/redirect-loop")).to be_nil
      expect(@log.string).to include("Link previews: Could not fetch #{@base}/redirect-loop: too many redirects")
      expect(@requests.count('/redirect-loop')).to eq(6)
    end

    it 'returns nil and warns for unreachable hosts' do
      port = TCPServer.open('127.0.0.1', 0) { |server| server.addr[1] }
      expect(previews.title("http://127.0.0.1:#{port}/")).to be_nil
      expect(@log.string).to include("Link previews: Could not fetch http://127.0.0.1:#{port}/:")
    end

    it 'downloads the favicon declared by the page' do
      expect(previews.favicon("#{@base}/page")).to eq('127.0.0.1.png')
      expect(File.binread(File.join(cache_dir, 'favicons', '127.0.0.1.png'))).to eq(PNG_BYTES)
    end

    it 'falls back to /favicon.ico' do
      expect(previews.favicon("#{@base}/untitled")).to eq('127.0.0.1.ico')
      expect(File.binread(File.join(cache_dir, 'favicons', '127.0.0.1.ico'))).to eq(ICO_BYTES)
    end

    it 'fetches each page only once when asked for both its title and favicon' do
      previews.title("#{@base}/page")
      previews.favicon("#{@base}/page")
      expect(@requests).to eq(['/page', '/static/icon.png'])
    end

    it 'returns nil and warns when no favicon can be obtained' do
      port = TCPServer.open('127.0.0.1', 0) { |server| server.addr[1] }
      expect(previews.favicon("http://127.0.0.1:#{port}/")).to be_nil
      expect(@log.string).to include("Link previews: No favicon found for 127.0.0.1")
    end

    describe 'caching' do
      it 'persists titles and favicons so a later build makes no requests' do
        previews.title("#{@base}/page")
        previews.favicon("#{@base}/page")
        previews.save
        @requests.clear

        cached = described_class.new(cache_dir)
        expect(cached.title("#{@base}/page")).to eq('Fish & Chips: “A History”')
        expect(cached.favicon("#{@base}/page")).to eq('127.0.0.1.png')
        expect(@requests).to be_empty
      end

      it 'caches failures' do
        previews.title("#{@base}/missing")
        previews.save
        @requests.clear
        @log.truncate(0)

        cached = described_class.new(cache_dir)
        expect(cached.title("#{@base}/missing")).to be_nil
        expect(@requests).to be_empty
        expect(@log.string).to be_empty
      end

      it 'caches favicons per host' do
        previews.favicon("#{@base}/page")
        @requests.clear
        expect(previews.favicon("#{@base}/og")).to eq('127.0.0.1.png')
        expect(@requests).to be_empty
      end

      it 'does not rewrite the cache files when nothing changed' do
        previews.title("#{@base}/page")
        previews.favicon("#{@base}/page")
        previews.save
        files = Dir.glob(File.join(cache_dir, '*.yml'))
        expect(files.size).to eq(2)
        past = Time.now - 3600
        File.utime(past, past, *files)

        cached = described_class.new(cache_dir)
        cached.title("#{@base}/page")
        cached.save
        files.each { |file| expect(File.mtime(file).to_i).to eq(past.to_i) }
      end
    end
  end

  describe '.annotate' do
    def annotate(html)
      described_class.annotate(html, 'numi.st', Jekyll::LinkPreviews::Previews.new(cache_dir))
    end

    it 'annotates external text links with a popover, a new tab target, and noopener' do
      output = annotate(%(<p>See <a href="#{@base}/page">this</a>.</p>))
      expect(output).to eq(
        %(<p>See <a href="#{@base}/page" class="link-preview" target="_blank" rel="noopener" ) +
        %(data-bs-content="&lt;img class=&quot;link-preview-favicon&quot; src=&quot;/assets/img/favicons/127.0.0.1.png&quot; alt=&quot;&quot;&gt;) +
        %(&lt;a href=&quot;#{@base}/page&quot; target=&quot;_blank&quot; rel=&quot;noopener&quot;&gt;) +
        %(Fish &amp;amp; Chips: “A History”&lt;/a&gt;">this</a>.</p>)
      )
    end

    it 'falls back to the URL as the title and omits a missing favicon' do
      port = TCPServer.open('127.0.0.1', 0) { |server| server.addr[1] }
      url = "http://127.0.0.1:#{port}/gone"
      output = annotate(%(<a href="#{url}">gone</a>))
      expect(output).to eq(
        %(<a href="#{url}" class="link-preview" target="_blank" rel="noopener" ) +
        %(data-bs-content="&lt;a href=&quot;#{url}&quot; target=&quot;_blank&quot; rel=&quot;noopener&quot;&gt;#{url}&lt;/a&gt;">gone</a>)
      )
      expect(@log.string).to include("Could not fetch #{url}")
      expect(@log.string).to include('No favicon found for 127.0.0.1')
    end

    it 'preserves existing attributes, classes, targets, and rel values' do
      output = annotate(%(<a class="u-url" href="#{@base}/page" target="_self" rel="me">x</a>))
      expect(output).to start_with(
        %(<a class="u-url link-preview" href="#{@base}/page" target="_self" rel="me noopener" data-bs-content=")
      )
    end

    it 'annotates links containing inline formatting without touching their content' do
      output = annotate(%(<a href="#{@base}/page"><code>&lt;T&gt;</code> &rsquo;s</a>))
      expect(output).to end_with(%("><code>&lt;T&gt;</code> &rsquo;s</a>))
      expect(output).to include('class="link-preview"')
    end

    it 'leaves internal links, icon links, comments, and scripts untouched' do
      html = <<~HTML
        <!DOCTYPE html>
        <a href="https://numi.st/post/">self</a>
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

    it 'annotates multiple links on one page' do
      output = annotate(%(<a href="#{@base}/page">one</a> and <a href="#{@base}/og">two</a>))
      expect(output.scan('class="link-preview"').size).to eq(2)
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
        <a href="#{@base}/page">external</a>
        <a href="http://example.com/self/">self</a>
      HTML
      File.write(File.join(@source, 'feed.xml'), <<~XML)
        ---
        ---
        <feed><a href="#{@base}/page">external</a></feed>
      XML
    end

    def build
      config = Jekyll.configuration(
        'source' => @source, 'destination' => File.join(@dir, '_site'),
        'url' => 'http://example.com', 'quiet' => true
      )
      Jekyll::Site.new(config).process
    end

    it 'annotates HTML pages, leaves other outputs alone, and publishes favicons' do
      build
      site = File.join(@dir, '_site')
      index = File.read(File.join(site, 'index.html'))
      expect(index).to include(%(<a href="#{@base}/page" class="link-preview" target="_blank" rel="noopener" data-bs-content="))
      expect(index).to include('<a href="http://example.com/self/">self</a>')
      expect(File.read(File.join(site, 'feed.xml'))).to eq(%(<feed><a href="#{@base}/page">external</a></feed>\n))
      expect(File.binread(File.join(site, 'assets/img/favicons/127.0.0.1.png'))).to eq(PNG_BYTES)
      expect(YAML.load_file(File.join(@source, '_link_previews/titles.yml'))).to eq(
        "#{@base}/page" => 'Fish & Chips: “A History”'
      )
    end

    it 'keeps favicons published on rebuilds' do
      build
      @requests.clear
      build
      expect(@requests).to be_empty
      expect(File.exist?(File.join(@dir, '_site/assets/img/favicons/127.0.0.1.png'))).to be true
    end
  end
end

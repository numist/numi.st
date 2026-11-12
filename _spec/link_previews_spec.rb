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
  GIF_BYTES = "GIF89afake gif".b
  JPG_BYTES = "\xFF\xD8\xFF\xE0fake jpg".b
  WEBP_BYTES = "RIFF\x10\x00\x00\x00WEBPVP8 fake".b
  SVG_BYTES = '<svg xmlns="http://www.w3.org/2000/svg"></svg>'.b

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
    { 'ico' => ICO_BYTES, 'png' => PNG_BYTES, 'gif' => GIF_BYTES, 'jpg' => JPG_BYTES, 'webp' => WEBP_BYTES }
      .each do |extension, bytes|
        serve.("/generic-#{extension}", 'text/html', icon_page.("/static/generic.#{extension}"))
        serve.("/static/generic.#{extension}", 'application/octet-stream', bytes)
      end
    serve.('/svg-icon', 'text/html', icon_page.('/static/icon.svg'))
    serve.('/static/icon.svg', 'image/svg+xml', SVG_BYTES)
    serve.('/generic-svg', 'text/html', icon_page.('/static/generic.svg'))
    serve.('/static/generic.svg', 'application/octet-stream', SVG_BYTES)
    serve.('/junk-icon', 'text/html', icon_page.('/static/junk'))
    serve.('/static/junk', 'application/octet-stream', 'not an image')
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

  def titles_path
    File.join(cache_dir, 'titles.yml')
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

    it 'fetches page titles' do
      expect(previews.title("#{@base}/page")).to eq('Fish & Chips: “A History”')
      expect(previews.title("#{@base}/og")).to eq('OG & Title')
      expect(previews.title("#{@base}/empty-title")).to eq('From OG')
      expect(previews.title("#{@base}/latin1")).to eq('Café')
      expect(previews.title("#{@base}/meta-charset")).to eq('“Quoted”')
      expect(@log.string).to be_empty
    end

    it 'follows redirects' do
      expect(previews.title("#{@base}/redirect")).to eq('Fish & Chips: “A History”')
    end

    it 'ignores the fragment when fetching' do
      expect(previews.title("#{@base}/page#section")).to eq('Fish & Chips: “A History”')
      expect(previews.title("#{@base}/page")).to eq('Fish & Chips: “A History”')
      expect(@requests).to eq(['/page'])
    end

    {
      '/untitled' => 'no title found',
      '/paper.pdf' => 'not HTML (application/pdf)',
      '/missing' => 'HTTP 404',
      '/redirect-loop' => 'too many redirects'
    }.each do |path, reason|
      it "returns nil and explains how to fix a missing title (#{reason})" do
        expect(previews.title("#{@base}#{path}")).to be_nil
        expect(@log.string).to include(
          "Link preview: no title for #{@base}#{path} (#{reason}); set one in _link_previews/titles.yml"
        )
      end
    end

    it 'stops following redirects after five' do
      previews.title("#{@base}/redirect-loop")
      expect(@requests.count('/redirect-loop')).to eq(6)
    end

    it 'returns nil and warns for unreachable hosts' do
      port = unused_port
      expect(previews.title("http://127.0.0.1:#{port}/")).to be_nil
      expect(@log.string).to match(
        %r{Link preview: no title for http://127\.0\.0\.1:#{port}/ \(.+\); set one in _link_previews/titles\.yml}
      )
    end

    it 'warns about a missing title once per URL' do
      3.times { previews.title("#{@base}/missing") }
      expect(@log.string.scan('no title for').size).to eq(1)
    end

    it 'downloads the favicon declared by the page' do
      expect(previews.favicon("#{@base}/page")).to eq('127.0.0.1.png')
      expect(File.binread(File.join(cache_dir, 'favicons', '127.0.0.1.png'))).to eq(PNG_BYTES)
    end

    it 'falls back to /favicon.ico' do
      expect(previews.favicon("#{@base}/untitled")).to eq('127.0.0.1.ico')
      expect(File.binread(File.join(cache_dir, 'favicons', '127.0.0.1.ico'))).to eq(ICO_BYTES)
    end

    %w[ico png gif jpg webp].each do |extension|
      it "recognizes #{extension} favicons served with a generic content type" do
        expect(previews.favicon("#{@base}/generic-#{extension}")).to eq("127.0.0.1.#{extension}")
        expect(@requests).to eq(["/generic-#{extension}", "/static/generic.#{extension}"])
      end
    end

    it 'rejects SVG favicons whatever their content type' do
      expect(previews.favicon("#{@base}/svg-icon")).to eq('127.0.0.1.ico')
      expect(described_class.new(File.join(@dir, 'other')).favicon("#{@base}/generic-svg")).to eq('127.0.0.1.ico')
    end

    it 'rejects favicons that are not recognizable images' do
      expect(previews.favicon("#{@base}/junk-icon")).to eq('127.0.0.1.ico')
    end

    it 'fetches each page only once when asked for both its title and favicon' do
      previews.title("#{@base}/page")
      previews.favicon("#{@base}/page")
      expect(@requests).to eq(['/page', '/static/icon.png'])
    end

    it 'returns nil and warns when no favicon can be obtained' do
      expect(previews.favicon("http://127.0.0.1:#{unused_port}/")).to be_nil
      expect(@log.string).to include('Link preview: no favicon found for 127.0.0.1')
    end

    describe 'caching' do
      it 'writes one hand-editable entry per URL, sorted' do
        previews.title("#{@base}/page")
        previews.title("#{@base}/missing")
        previews.save
        expect(File.read(titles_path)).to eq(<<~YAML)
          ---
          #{@base}/missing:
            title:
            error: HTTP 404
          #{@base}/page:
            title: 'Fish & Chips: “A History”'
        YAML
      end

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

      it 'never refetches failures, but warns about them on every build' do
        previews.title("#{@base}/missing")
        previews.save
        @requests.clear
        @log.truncate(0)
        @log.rewind

        cached = described_class.new(cache_dir)
        expect(cached.title("#{@base}/missing")).to be_nil
        expect(@requests).to be_empty
        expect(@log.string).to include("no title for #{@base}/missing (HTTP 404); set one in _link_previews/titles.yml")
      end

      it 'uses hand-filled titles without fetching or warning' do
        FileUtils.mkdir_p(cache_dir)
        File.write(titles_path, <<~YAML)
          #{@base}/missing:
            title: Filled In By Hand
            error: HTTP 404
        YAML
        expect(previews.title("#{@base}/missing")).to eq('Filled In By Hand')
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

      it 'does not reformat a hand-edited cache file when nothing changed' do
        FileUtils.mkdir_p(cache_dir)
        hand_written = "#{@base}/missing:\n  error: HTTP 404\n  title: \"By Hand\"\n"
        File.write(titles_path, hand_written)
        previews.title("#{@base}/missing")
        previews.save
        expect(File.read(titles_path)).to eq(hand_written)
      end
    end
  end

  describe '.annotate' do
    def annotate(html)
      described_class.annotate(html, Jekyll::LinkPreviews::Previews.new(cache_dir))
    end

    def article(html)
      %(<article class="post">#{html}</article>)
    end

    it 'annotates external text links with a popover, a new tab target, and noopener' do
      output = annotate(article(%(<p>See <a href="#{@base}/page">this</a>.</p>)))
      expect(output).to eq(article(
        %(<p>See <a href="#{@base}/page" class="link-preview" target="_blank" rel="noopener" ) +
        %(data-bs-content="&lt;img class=&quot;link-preview-favicon&quot; src=&quot;/assets/img/favicons/127.0.0.1.png&quot; alt=&quot;&quot;&gt;) +
        %(&lt;a href=&quot;#{@base}/page&quot; target=&quot;_blank&quot; rel=&quot;noopener&quot;&gt;) +
        %(Fish &amp;amp; Chips: “A History”&lt;/a&gt;">this</a>.</p>)
      ))
    end

    it 'falls back to the URL as the title and omits a missing favicon' do
      url = "http://127.0.0.1:#{unused_port}/gone"
      output = annotate(article(%(<a href="#{url}">gone</a>)))
      expect(output).to eq(article(
        %(<a href="#{url}" class="link-preview" target="_blank" rel="noopener" ) +
        %(data-bs-content="&lt;a href=&quot;#{url}&quot; target=&quot;_blank&quot; rel=&quot;noopener&quot;&gt;#{url}&lt;/a&gt;">gone</a>)
      ))
      expect(@log.string).to include("no title for #{url}")
      expect(@log.string).to include('no favicon found for 127.0.0.1')
    end

    it 'uses a title attribute as the popover title without fetching or caching it' do
      Jekyll::LinkPreviews::Previews.new(cache_dir).tap { |cached| cached.favicon("#{@base}/og") }.save
      FileUtils.rm(titles_path)
      @requests.clear
      previews = Jekyll::LinkPreviews::Previews.new(cache_dir)
      output = described_class.annotate(
        article(%(<a href="#{@base}/missing" title="  Inline &amp;  Title ">x</a>)), previews
      )
      previews.save
      expect(output).to eq(article(
        %(<a href="#{@base}/missing" class="link-preview" target="_blank" rel="noopener" ) +
        %(data-bs-content="&lt;img class=&quot;link-preview-favicon&quot; src=&quot;/assets/img/favicons/127.0.0.1.ico&quot; alt=&quot;&quot;&gt;) +
        %(&lt;a href=&quot;#{@base}/missing&quot; target=&quot;_blank&quot; rel=&quot;noopener&quot;&gt;) +
        %(Inline &amp;amp; Title&lt;/a&gt;">x</a>)
      ))
      expect(@requests).to be_empty
      expect(@log.string).to be_empty
      expect(YAML.load_file(titles_path)).to be_empty
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

    it 'annotates HTML pages, leaves other outputs alone, and publishes favicons' do
      build
      site = File.join(@dir, '_site')
      index = File.read(File.join(site, 'index.html'))
      expect(index).to include(%(<a href="#{@base}/page" class="link-preview" target="_blank" rel="noopener" data-bs-content="))
      expect(index).to include(%(<footer><a href="#{@base}/og">footer</a></footer>))
      expect(File.read(File.join(site, 'feed.xml'))).to eq(
        %(<feed><article><a href="#{@base}/page">external</a></article></feed>\n)
      )
      expect(File.binread(File.join(site, 'assets/img/favicons/127.0.0.1.png'))).to eq(PNG_BYTES)
      expect(YAML.load_file(File.join(@source, '_link_previews/titles.yml'))).to eq(
        "#{@base}/page" => { 'title' => 'Fish & Chips: “A History”' }
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

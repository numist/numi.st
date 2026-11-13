# ABOUTME: Tests for the link previews plugin: link classification, HTML annotation, page title, favicon, and fragment
# ABOUTME: fetching against a local HTTP server, the on-disk cache, and previews of the site's own pages and files.
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
    serve.('/sections', 'text/html',
           '<html><head><title>Sections</title><link rel="icon" href="/static/icon.png"></head><body>' \
           '<h2 id="intro">The Introduction</h2><div id="note">A note</div><p>The quick brown fox.</p></body></html>')
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

  # Starting the server may have failed, and that failure should be what's reported
  after(:all) do
    @server&.shutdown
    @thread&.join
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

    it 'does not treat relative paths, fragments, or other schemes as external' do
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

    it 'does not treat unparseable hrefs as external' do
      expect(external?('https://exa mple.com/%%')).to be false
    end
  end

  describe '.internal?' do
    def internal?(href)
      described_class.internal?(href)
    end

    it 'treats paths, relative paths, fragments, queries, and empty hrefs as internal' do
      expect(internal?('/about/')).to be true
      expect(internal?('post/2022/x/')).to be true
      expect(internal?('../paper.pdf')).to be true
      expect(internal?('#section')).to be true
      expect(internal?('?q=1')).to be true
      expect(internal?('')).to be true
    end

    it 'does not treat links with a scheme or host, or missing hrefs, as internal' do
      expect(internal?('https://numi.st/post/2025/airbags/')).to be false
      expect(internal?('//example.com/path')).to be false
      expect(internal?('mailto:blog@numist.net')).to be false
      expect(internal?('tel:+15555550100')).to be false
      expect(internal?('javascript:void(0)')).to be false
      expect(internal?('https://exa mple.com/%%')).to be false
      expect(internal?(nil)).to be false
    end
  end

  describe '.literal_in_source?' do
    def literal?(href, source)
      described_class.literal_in_source?(source, href, %(<a href="#{href}">))
    end

    it 'finds URLs followed by punctuation that ends them, as in YAML flow collections and tables' do
      expect(literal?('https://e.com/a', 'links: [https://e.com/a, https://e.com/b]')).to be true
      expect(literal?('https://e.com/b', 'links: [https://e.com/a, https://e.com/b]')).to be true
      expect(literal?('https://e.com/c', 'link: {url: https://e.com/c}')).to be true
      expect(literal?('https://e.com/d', '| https://e.com/d|')).to be true
      expect(literal?('https://e.com/e', 'see https://e.com/e; also')).to be true
    end

    it 'does not find a URL that only starts a longer URL' do
      expect(literal?('https://e.com/a', 'https://e.com/ab')).to be false
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

  describe Jekyll::LinkPreviews::LinkedPage do
    it 'finds the text a reader sees on the page once, however many fragments look for it' do
      page = described_class.new(Jekyll::LinkPreviews.parse('<p>One</p><p>two</p>'.b, 'UTF-8'))
      expect(page.text).to eq('One two')
      expect(page.text).to be(page.text)
    end
  end

  describe Jekyll::LinkPreviews::Fragment do
    def fragment(href)
      described_class.parse(href)
    end

    def resolve(href, body)
      html = "<html><head><title>Page</title></head><body>#{body}</body></html>"
      fragment(href).resolve(Jekyll::LinkPreviews::LinkedPage.new(Jekyll::LinkPreviews.parse(html.b, 'UTF-8')))
    end

    describe '.parse' do
      it 'finds no fragment in a URL without one' do
        expect(fragment('https://e.com/a')).to be_nil
        expect(fragment('https://e.com/a#')).to be_nil
        expect(fragment('')).to be_nil
      end

      it 'keys an element fragment by its percent-decoded id' do
        expect(fragment('/a/#caf%C3%A9%20menu').key).to eq('café menu')
        expect(fragment('#fn:socials').key).to eq('fn:socials')
        expect(fragment('#fn:socials').quote?).to be false
      end

      it 'keys a text fragment by its percent-decoded directives, keeping the :~: that marks them' do
        expect(fragment('https://e.com/#:~:text=a%20b,-c').key).to eq(':~:text=a b,-c')
        expect(fragment('https://e.com/#:~:text=a%20b,-c').quote?).to be true
      end

      it 'keeps encoded in keys what would otherwise read as directive syntax or a percent-encoding' do
        expect(fragment('#:~:text=a,b').key).to eq(':~:text=a,b')
        expect(fragment('#:~:text=a%2cb').key).to eq(':~:text=a%2Cb')
        expect(fragment('#:~:text=a%2D%41,-b%26c').key).to eq(':~:text=a%2DA,-b%26c')
        expect(fragment('#a%252Cb').key).to eq('a%252Cb')
        expect(fragment('#a%2Cb').key).to eq('a%2Cb')
        expect(fragment('#%3a~%3Atext=x').key).to eq('%3A~%3Atext=x')
        expect(fragment('#%3a~%3Atext=x').quote?).to be false
      end

      it 'lets a text directive take precedence over an element id before it' do
        expect(fragment('https://e.com/#intro:~:text=fox').key).to eq(':~:text=fox')
        expect(fragment('https://e.com/#intro:~:text=fox').quote?).to be true
      end

      it 'uses the element id when the directives include no valid text directive' do
        expect(fragment('#intro:~:other=x').key).to eq('intro')
        expect(fragment('#intro:~:text=').key).to eq('intro')
        expect(fragment('#:~:text=a,b,c')).to be_nil
      end
    end

    describe '#fallback' do
      it 'is the decoded id, quoted text, or start and end of a quoted range' do
        expect(fragment('#fn%3Asocials').fallback).to eq('fn:socials')
        expect(fragment('#:~:text=quick%20brown').fallback).to eq('quick brown')
        expect(fragment('#:~:text=the-,quick%2C,lazy%2Ddog,-.').fallback).to eq('quick, … lazy-dog')
      end

      it 'uses the first of several text directives' do
        expect(fragment('#:~:text=quick&text=lazy').fallback).to eq('quick')
        expect(fragment('#:~:other=x&text=lazy').fallback).to eq('lazy')
      end
    end

    describe '#resolve' do
      let(:body) do
        <<~HTML
          <h2 id="intro">  The
            <em>Introduction</em> </h2>
          <div id="note">A note</div><h3 id="café">Menu</h3>
          <p><a name="legacy"></a>The quick <em>brown</em> fox jumps over the lazy&nbsp;dog.</p>
          <p>The quick red fox naps.</p>
          <script>var words = "hidden text";</script><style>.hidden-style {}</style>
        HTML
      end

      it 'names a heading by its text' do
        expect(resolve('#intro', body)).to eq('The Introduction')
        expect(resolve('#caf%C3%A9', body)).to eq('Menu')
      end

      it 'names a heading without the permalink glyphs before or after its text, or by its id if it has no text' do
        page = <<~HTML
          <h2 id="spaced">Spaced <a href="#spaced">¶</a></h2>
          <h2 id="glued">Glued<a href="#glued">¶</a></h2>
          <h2 id="leading"><a href="#leading">#</a> Leading §</h2>
          <h2 id="plain">🔗 Plain ¶ #</h2>
          <h2 id="c-sharp">C# and F#</h2>
          <h2 id="glyph-word">#hashtag</h2>
          <h2 id="glyphs"><a href="#glyphs">¶</a></h2>
          <h2 id="empty"> <a href="#empty"></a> </h2>
        HTML
        expect(%w[spaced glued leading plain c-sharp glyph-word glyphs empty].map { |id| resolve("##{id}", page) }).to eq(
          ['Spaced', 'Glued', 'Leading', 'Plain', 'C# and F#', '#hashtag', 'glyphs', 'empty']
        )
      end

      it 'names other elements, including named anchors, by their id' do
        expect(resolve('#note', body)).to eq('note')
        expect(resolve('#legacy', body)).to eq('legacy')
      end

      it 'finds nothing for an id that is not on the page' do
        expect(resolve('#gone', body)).to be_nil
      end

      it 'quotes text as the page writes it, ignoring differences in case and whitespace' do
        expect(resolve('#:~:text=QUICK%20%20brown', body)).to eq('quick brown')
        expect(resolve('#:~:text=lazy%20dog', body)).to eq('lazy dog')
      end

      it 'separates the text of blocks and lines, but not of inline elements, however tightly the page is written' do
        page = '<div><p>end of one</p><p>Start of <b>t</b>wo</p></div><ul><li>three</li><li>four<br>five</li></ul>'
        expect(resolve('#:~:text=one%20start%20of%20two', page)).to eq('one Start of two')
        expect(resolve('#:~:text=two%20three%20four%20five', page)).to eq('two three four five')
        expect(resolve('#:~:text=onestart', page)).to be_nil
      end

      it 'quotes a range from the start of its first text through the end of its last' do
        expect(resolve('#:~:text=quick,dog', body)).to eq('quick brown fox jumps over the lazy dog')
        expect(resolve('#:~:text=jumps,naps', body)).to eq('jumps over the lazy dog. The quick red fox naps')
      end

      it 'uses a prefix and suffix only to choose which text to quote' do
        expect(resolve('#:~:text=dog.%20The-,quick,fox', body)).to eq('quick red fox')
        expect(resolve('#:~:text=quick,-red', body)).to eq('quick')
      end

      it 'ends a range at the first end followed by the suffix, rather than moving on to a later start' do
        expect(resolve('#:~:text=quick,fox,-naps', body)).to eq('quick brown fox jumps over the lazy dog. The quick red fox')
        expect(resolve('#:~:text=alpha,beta,-delta', '<p>alpha beta gamma beta delta</p>')).to eq('alpha beta gamma beta')
      end

      it 'matches only whole words, in any script, at the edges of the text it quotes and of its prefix and suffix' do
        expect(resolve('#:~:text=cat', '<p>conCATenate a Cat</p>')).to eq('Cat')
        expect(resolve('#:~:text=caf', '<p>café</p>')).to be_nil
        expect(resolve('#:~:text=jumps,do', body)).to be_nil
        expect(resolve('#:~:text=he-,quick', body)).to be_nil
        expect(resolve('#:~:text=quick,-re', body)).to be_nil
        expect(resolve('#:~:text=quick,fox,-nap', body)).to be_nil
      end

      it 'needs no word boundary beside punctuation' do
        expect(resolve('#:~:text=.%20The%20quick%20red', body)).to eq('. The quick red')
        expect(resolve('#:~:text=lazy-,dog.,-The', body)).to eq('dog.')
      end

      it 'finds nothing for text that is not on the page, or is only in its head, scripts, or styles' do
        %w[purple quick,purple Page hidden].each do |text|
          expect(resolve("#:~:text=#{text}", body)).to be_nil
        end
      end
    end
  end

  describe Jekyll::LinkPreviews::Previews do
    subject(:previews) { described_class.new(cache_dir) }

    def report(previews_to_report = previews)
      previews_to_report.report
      @log.string
    end

    def fix_hint
      'set title: and remove error: in _link_previews/links.yml, or delete the entry to retry'
    end

    # Serves a titled page from a host with no favicon at all.
    def with_iconless_server
      server = WEBrick::HTTPServer.new(
        BindAddress: '127.0.0.1', Port: 0, Logger: WEBrick::Log.new(StringIO.new), AccessLog: []
      )
      server.mount_proc('/titled') do |_, response|
        response['Content-Type'] = 'text/html'
        response.body = '<html><head><title>Iconless</title></head></html>'
      end
      thread = Thread.new { server.start }
      begin
        yield "http://127.0.0.1:#{server.config[:Port]}"
      ensure
        server.shutdown
        thread.join
      end
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
        expect(report).to include("Link preview: #{@base}#{path}: no title (#{reason}); #{fix_hint}")
      end
    end

    it 'stops following redirects after five' do
      previews.title("#{@base}/redirect-loop")
      expect(@requests.count('/redirect-loop')).to eq(6)
    end

    it 'records why the title is missing for unreachable hosts' do
      url = "http://127.0.0.1:#{unused_port}/"
      expect(previews.title(url)).to be_nil
      expect(previews.favicon(url)).to be_nil
      warnings = report
      expect(warnings.lines.size).to eq(1)
      expect(warnings).to match(
        %r{Link preview: #{Regexp.escape(url)}: no title \(Failed to open TCP connection to .+\); #{Regexp.escape(fix_hint)}\n\z}
      )
    end

    it 'does not track favicons that cannot be found' do
      with_iconless_server do |base|
        expect(previews.title("#{base}/titled")).to eq('Iconless')
        expect(previews.favicon("#{base}/titled")).to be_nil
        previews.save
        expect(YAML.load_file(links_path).fetch("#{base}/titled")).to eq('title' => 'Iconless')
        expect(report).to be_empty
      end
    end

    it 'gives up on pages that respond too slowly, recording a clean error' do
      slow = described_class.new(cache_dir, timeout: 0.1)
      expect(slow.title("#{@base}/slow")).to be_nil
      slow.save
      expect(YAML.load_file(links_path).fetch("#{@base}/slow")).to eq(
        'title' => nil, 'favicon' => favicon_name(ico_bytes, 'ico'), 'error' => 'Net::ReadTimeout'
      )
      expect(report(slow)).to include("Link preview: #{@base}/slow: no title (Net::ReadTimeout); #{fix_hint}")
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
        expect(YAML.load_file(links_path).fetch("#{@base}/video.mp4")['error']).to eq('not HTML (video/mp4)')
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
      expect(report).to include("Link preview: https:#{href}: no title (")
    end

    it 'warns once per URL per build' do
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
            error: HTTP 404
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
        expect(report(cached)).to include("Link preview: #{@base}/missing: no title (HTTP 404); #{fix_hint}")
      end

      it 'uses hand-filled titles and favicons without fetching or warning' do
        write_links(<<~YAML)
          #{@base}/missing:
            title: Filled In By Hand
            favicon: by-hand.png
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
          Jekyll::LinkPreviews::PreviewDataError,
          %(_link_previews/links.yml: the entry for #{@base}/page must be a mapping with title: and favicon:, not "Some Title")
        )
      end

      it 'fails on favicon names that are not plain file names in the favicons directory' do
        ['../outside.png', 'sub/inside.png', '.hidden.png', 123].each do |name|
          write_links({ "#{@base}/page" => { 'title' => 'Page', 'favicon' => name } }.to_yaml)
          expect { described_class.new(cache_dir) }.to raise_error(
            Jekyll::LinkPreviews::PreviewDataError,
            "_link_previews/links.yml: the favicon for #{@base}/page must be a file name in _link_previews/favicons/, " \
            "not #{name.inspect}"
          )
        end
      end

      it 'fails on a cache file that is not a mapping' do
        write_links("- #{@base}/page\n")
        expect { previews }.to raise_error(
          Jekyll::LinkPreviews::PreviewDataError, '_link_previews/links.yml must be a mapping of URLs to entries'
        )
      end

      it 'fails on an entry naming a favicon file that does not exist' do
        write_links("#{@base}/page:\n  title: Page\n  favicon: gone.png\n")
        expect { previews }.to raise_error(
          Jekyll::LinkPreviews::PreviewDataError,
          "_link_previews/links.yml: the favicon for #{@base}/page, gone.png, is not a file in _link_previews/favicons/"
        )
      end

      it 'treats an entry with an error as having no title, keeping the title in the file' do
        hand_written = "#{@base}/walled:\n  title: Browser Verification\n  favicon:\n  error: bot wall\n"
        write_links(hand_written)
        expect(previews.title("#{@base}/walled")).to be_nil
        previews.save
        expect(File.read(links_path)).to eq(hand_written)
        expect(@requests).to be_empty
        warnings = report
        expect(warnings.lines.size).to eq(1)
        expect(warnings).to end_with("Link preview: #{@base}/walled: no title (bot wall); #{fix_hint}\n")
      end

      it 'treats a blank or null favicon as no favicon' do
        write_links("#{@base}/page:\n  title: Page\n  favicon:\n#{@base}/og:\n  title: OG\n  favicon: ''\n")
        expect(previews.favicon("#{@base}/page")).to be_nil
        expect(previews.favicon("#{@base}/og")).to be_nil
        expect(previews.favicon_files).to be_empty
        expect(@requests).to be_empty
        expect(report).to be_empty
      end

      it 'fails on an entry naming a directory as its favicon' do
        write_links("#{@base}/page:\n  title: Page\n  favicon: folder\n")
        FileUtils.mkdir_p(File.join(cache_dir, 'favicons', 'folder'))
        expect { previews }.to raise_error(
          Jekyll::LinkPreviews::PreviewDataError,
          "_link_previews/links.yml: the favicon for #{@base}/page, folder, is not a file in _link_previews/favicons/"
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

      describe 'fragments' do
        def fragment(href)
          previews.fragment(href, Jekyll::LinkPreviews::Fragment.parse(href))
        end

        it 'finds fragments in the page fetched for its title, caching them sorted in its entry' do
          expect(previews.title("#{@base}/sections#note")).to eq('Sections')
          expect(fragment("#{@base}/sections#note")).to eq('note')
          expect(fragment("#{@base}/sections#intro")).to eq('The Introduction')
          expect(fragment("#{@base}/sections#:~:text=QUICK")).to eq('quick')
          expect(@requests).to eq(['/sections', '/static/icon.png'])
          previews.save
          expect(File.read(links_path)).to eq(<<~YAML)
            ---
            #{@base}/sections:
              title: Sections
              favicon: #{favicon_name(png_bytes, 'png')}
              fragments:
                ":~:text=QUICK": quick
                intro: The Introduction
                note: note
          YAML
        end

        it 'caches a fragment that is not on the page as null, and does not refetch it' do
          expect(fragment("#{@base}/sections#gone")).to be_nil
          previews.save
          expect(YAML.load_file(links_path).fetch("#{@base}/sections")['fragments']).to eq('gone' => nil)
          @requests.clear

          cached = described_class.new(cache_dir)
          expect(cached.fragment("#{@base}/sections#gone", Jekyll::LinkPreviews::Fragment.parse('#gone'))).to be_nil
          expect(@requests).to be_empty
        end

        it 'fetches the page for a fragment not yet cached, keeping the title and favicon cached for it' do
          write_links("#{@base}/sections:\n  title: By Hand\n  favicon:\n")
          expect(fragment("#{@base}/sections#intro")).to eq('The Introduction')
          expect(@requests).to eq(['/sections'])
          previews.save
          expect(YAML.load_file(links_path).fetch("#{@base}/sections")).to eq(
            'title' => 'By Hand', 'favicon' => nil, 'fragments' => { 'intro' => 'The Introduction' }
          )
        end

        it 'caches a fragment of a page that cannot be fetched as null' do
          write_links("#{@base}/missing:\n  title: By Hand\n")
          expect(fragment("#{@base}/missing#intro")).to be_nil
          previews.save
          expect(YAML.load_file(links_path).fetch("#{@base}/missing")).to eq(
            'title' => 'By Hand', 'fragments' => { 'intro' => nil }
          )
        end

        it 'uses hand-set fragments, treating blank ones as not on the page, without fetching' do
          write_links(<<~YAML)
            #{@base}/sections:
              title: Sections
              fragments:
                intro: By Hand
                note: ''
                gone:
          YAML
          expect(fragment("#{@base}/sections#intro")).to eq('By Hand')
          expect(fragment("#{@base}/sections#note")).to be_nil
          expect(fragment("#{@base}/sections#gone")).to be_nil
          expect(@requests).to be_empty
        end

        it 'leaves the other entries byte-for-byte unchanged when caching a fragment' do
          other_entries = <<~YAML
            #{@base}/missing:
              title:
              favicon: #{favicon_name(ico_bytes, 'ico')}
              error: HTTP 404
            #{@base}/page:
              title: 'Fish & Chips: “A History”'
              favicon: #{favicon_name(png_bytes, 'png')}
          YAML
          write_links("---\n#{other_entries}")
          File.binwrite(File.join(cache_dir, 'favicons', favicon_name(ico_bytes, 'ico')), ico_bytes)
          File.binwrite(File.join(cache_dir, 'favicons', favicon_name(png_bytes, 'png')), png_bytes)
          fragment("#{@base}/sections#intro")
          previews.save
          expect(File.read(links_path)).to eq(<<~YAML)
            ---
            #{other_entries}#{@base}/sections:
              title: Sections
              favicon: #{favicon_name(png_bytes, 'png')}
              fragments:
                intro: The Introduction
          YAML
        end

        it 'fails on fragments that are not a mapping of text to text' do
          ['intro', { 'intro' => 2024 }, { 1 => 'Foo' }].each do |fragments|
            write_links({ "#{@base}/sections" => { 'title' => 'Sections', 'fragments' => fragments } }.to_yaml)
            expect { described_class.new(cache_dir) }.to raise_error(
              Jekyll::LinkPreviews::PreviewDataError,
              "_link_previews/links.yml: the fragments for #{@base}/sections must be a mapping of fragments to text, " \
              "not #{fragments.inspect}"
            )
          end
        end
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

    it 'shows the URL, and any favicon, for a link whose entry has an error despite having a title' do
      FileUtils.mkdir_p(File.join(cache_dir, 'favicons'))
      File.binwrite(File.join(cache_dir, 'favicons', 'walled.png'), png_bytes)
      File.write(links_path, "#{@base}/walled:\n  title: Browser Verification\n  favicon: walled.png\n  error: bot wall\n")
      output = annotate(article(%(<a href="#{@base}/walled">x</a>)))
      expect(output).to include(
        %(rel=&quot;noopener&quot;&gt;#{@base}/walled&lt;/a&gt;" data-favicon="/assets/img/favicons/walled.png">x</a>)
      )
      expect(output).not_to include('Browser Verification')
      expect(@requests).to be_empty
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
      expect(@log.string).to include("Link preview: #{url}: no title (")
    end

    it 'shows a title attribute instead of the page title, without caching it, while still fetching the URL for its favicon' do
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

    describe 'data-preview-favicon' do
      before do
        FileUtils.mkdir_p(File.join(cache_dir, 'favicons'))
        File.binwrite(File.join(cache_dir, 'favicons', 'inline.png'), png_bytes)
      end

      it 'shows the named favicon instead of the cached favicon, without caching it, and removes the attribute' do
        output = annotate(article(%(<a href="#{@base}/page" data-preview-favicon=" inline.png ">x</a>)))
        previews.save
        expect(output).to eq(article(
          %(<a href="#{@base}/page" class="link-preview" target="_blank" rel="noopener" ) +
          %(data-bs-content="&lt;img class=&quot;link-preview-favicon&quot; src=&quot;/assets/img/favicons/inline.png&quot; alt=&quot;&quot;&gt;) +
          %(&lt;a href=&quot;#{@base}/page&quot; target=&quot;_blank&quot; rel=&quot;noopener&quot;&gt;) +
          %(Fish &amp;amp; Chips: “A History”&lt;/a&gt;" data-favicon="/assets/img/favicons/inline.png">x</a>)
        ))
        expect(YAML.load_file(links_path).fetch("#{@base}/page")['favicon']).to eq(favicon_name(png_bytes, 'png'))
        expect(previews.favicon_files).to include('inline.png')
      end

      it 'removes an empty or blank attribute and shows the cached favicon' do
        ['', '  '].each do |name|
          output = annotate(article(%(<a href="#{@base}/page" data-preview-favicon="#{name}">x</a>)))
          expect(output).not_to include('data-preview-favicon')
          expect(output).to include(%( data-favicon="/assets/img/favicons/#{favicon_name(png_bytes, 'png')}">x</a>))
        end
      end

      it 'lists a favicon named both inline and by a cache entry once' do
        File.write(links_path, "#{@base}/page:\n  title: Page\n  favicon: inline.png\n")
        annotate(article(%(<a href="#{@base}/page" data-preview-favicon="inline.png">x</a>)))
        expect(previews.favicon_files).to eq(['inline.png'])
      end

      it 'shows the named favicon for a link whose cache entry has no favicon' do
        File.write(links_path, "#{@base}/page:\n  title: Page\n  favicon:\n")
        output = annotate(article(%(<a href="#{@base}/page" data-preview-favicon="inline.png">x</a>)))
        expect(output).to include(%(rel=&quot;noopener&quot;&gt;Page&lt;/a&gt;" data-favicon="/assets/img/favicons/inline.png">x</a>))
        expect(@requests).to be_empty
      end

      it 'neither fetches nor caches a link that names its own title and favicon' do
        output = annotate(article(%(<a href="#{@base}/page" title="Inline" data-preview-favicon="inline.png">x</a>)))
        previews.report
        previews.save
        expect(output).to include(%(rel=&quot;noopener&quot;&gt;Inline&lt;/a&gt;" data-favicon="/assets/img/favicons/inline.png">x</a>))
        expect(@requests).to be_empty
        expect(YAML.load_file(links_path)).not_to have_key("#{@base}/page")
        expect(@log.string).to be_empty
      end

      it 'fails on a name that is not a file in the favicons directory, naming the page' do
        annotate_with_favicon = lambda do |name|
          described_class.annotate(
            article(%(<a href="#{@base}/page" data-preview-favicon="#{name}">x</a>)), previews, page: 'notes/page.md'
          )
        end
        expect { annotate_with_favicon.('gone.png') }.to raise_error(
          Jekyll::LinkPreviews::PreviewDataError,
          "notes/page.md: the data-preview-favicon for #{@base}/page, gone.png, is not a file in _link_previews/favicons/"
        )
        expect { annotate_with_favicon.('../inline.png') }.to raise_error(
          Jekyll::LinkPreviews::PreviewDataError,
          "notes/page.md: the data-preview-favicon for #{@base}/page must be a file name in _link_previews/favicons/, " \
          'not "../inline.png"'
        )
      end
    end

    describe 'fragments' do
      before { FileUtils.mkdir_p(cache_dir) }

      def popover(output)
        Nokogiri::HTML5.fragment(Nokogiri::HTML5.fragment(output).at_css('a')['data-bs-content'])
      end

      def annotate_page(html, cache = previews)
        described_class.annotate(article(html), cache, page: 'notes/page.md')
      end

      def fix_hint
        'set its value under fragments: in _link_previews/links.yml, or delete it to retry'
      end

      it 'appends the heading text or id that an element fragment names to the title' do
        heading = popover(annotate(article(%(<a href="#{@base}/sections#intro">x</a>))))
        expect(heading.at_css('a').text).to eq('Sections # The Introduction')
        expect(heading.at_css('a')['href']).to eq("#{@base}/sections#intro")
        expect(heading.at_css('blockquote')).to be_nil
        expect(popover(annotate(article(%(<a href="#{@base}/sections#note">x</a>)))).at_css('a').text).to eq('Sections # note')
        expect(@log.string).to be_empty
      end

      it 'appends the id and warns on every build, naming the page and link, when the id is not on the page' do
        output = annotate_page(%(<a href="#{@base}/sections#gone">x</a>))
        previews.save
        annotate_page(%(<a href="#{@base}/sections#gone">x</a>), Jekyll::LinkPreviews::Previews.new(cache_dir))
        expect(popover(output).at_css('a').text).to eq('Sections # gone')
        expect(@log.string.scan(
          "Link preview: notes/page.md links to #{@base}/sections#gone, " \
          "but an element with the id \"gone\" could not be found on the page it links to; #{fix_hint}"
        ).size).to eq(2)
      end

      it 'quotes the text that a text fragment names below the title' do
        output = annotate(article(%(<a href="#{@base}/sections#:~:text=QUICK%20brown">x</a>)))
        expect(output).to include(
          %(Sections&lt;/a&gt;&lt;blockquote class=&quot;link-preview-quote&quot;&gt;quick brown&lt;/blockquote&gt;")
        )
        expect(popover(output).at_css('a').text).to eq('Sections')
        expect(@log.string).to be_empty
      end

      it 'quotes the start and end of a range that is not on the page, and warns' do
        output = annotate_page(%(<a href="#{@base}/sections#:~:text=quick,purple">x</a>))
        expect(popover(output).at_css('blockquote').text).to eq('quick … purple')
        expect(@log.string).to include(
          "Link preview: notes/page.md links to #{@base}/sections#:~:text=quick,purple, " \
          "but the text it quotes could not be found on the page it links to; #{fix_hint}"
        )
      end

      it 'shows the URL and the fragment as written for an entry with an error, without fetching or warning about it' do
        File.write(links_path, "#{@base}/sections:\n  title: Walled\n  error: bot wall\n")
        element = annotate_page(%(<a href="#{@base}/sections#intro">x</a>))
        quote = annotate_page(%(<a href="#{@base}/sections#:~:text=quick">x</a>))
        expect(popover(element).at_css('a').text).to eq("#{@base}/sections#intro")
        expect(popover(quote).at_css('a').text).to eq("#{@base}/sections#:~:text=quick")
        expect(popover(quote).at_css('blockquote').text).to eq('quick')
        expect(@requests).to be_empty
        expect(@log.string).to be_empty
      end

      it 'shows an inline title in place of the whole title, still quoting text' do
        element = annotate(article(%(<a href="#{@base}/sections#intro" title="Inline">x</a>)))
        quote = annotate(article(%(<a href="#{@base}/sections#:~:text=quick" title="Inline">x</a>)))
        expect(popover(element).at_css('a').text).to eq('Inline')
        expect(popover(quote).at_css('a').text).to eq('Inline')
        expect(popover(quote).at_css('blockquote').text).to eq('quick')
      end

      it 'does not fetch for the element fragment of a link that names its own title and favicon' do
        FileUtils.mkdir_p(File.join(cache_dir, 'favicons'))
        File.binwrite(File.join(cache_dir, 'favicons', 'inline.png'), png_bytes)
        annotate(article(%(<a href="#{@base}/sections#intro" title="Inline" data-preview-favicon="inline.png">x</a>)))
        expect(@requests).to be_empty
      end

      it 'escapes markup in quotes and fragment text' do
        File.write(links_path, <<~YAML)
          #{@base}/sections:
            title: Sections
            fragments:
              ":~:text=x": <img src=x>
              intro: <img src=y>
        YAML
        quote = annotate(article(%(<a href="#{@base}/sections#:~:text=x">x</a>)))
        element = annotate(article(%(<a href="#{@base}/sections#intro">x</a>)))
        expect(popover(quote).at_css('blockquote').text).to eq('<img src=x>')
        expect(popover(element).at_css('a').text).to eq('Sections # <img src=y>')
        expect(popover(quote).at_css('img')).to be_nil
        expect(popover(element).at_css('img')).to be_nil
      end
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

      it 'does not mistake a trailing slash in an unquoted value for a self-closing tag' do
        output = annotate(article(%(<p><a href=#{@base}/page/>x</a></p>)))
        expect(annotated_links(output)).to eq(1)
      end

      it 'accepts apostrophes in unquoted values' do
        html = article(%(<p title=it's>a</p><p title='quoted'>b</p>))
        expect(annotate(html)).to eq(html)
      end

      it 'accepts self-closing tags written right after the tag name or a quote' do
        html = article(%(<p>a<x/><y z="1"/><w /></p>))
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

      it 'fails on a tag it cannot parse, pointing at that tag' do
        expect { annotate_page(%(<p>\n<a href="#{@base}/page"=>x</a></p>)) }.to raise_error(
          markup_error, 'notes/page.md:2: unparseable tag'
        )
      end

      it 'fails at a stray < in text, rather than treating it as part of a tag name' do
        expect { annotate_page(%(<article><p>\nx<y</p></article>)) }.to raise_error(
          markup_error, 'notes/page.md:2: unparseable tag'
        )
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

    it 'leaves non-http links, icon links, comments, and scripts untouched' do
      html = article(<<~HTML)
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
          A [generated prefix]({{ site.generated }}/long) of a [longer literal link](#{@base}/long-title).

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
        expect(output.scan('class="link-preview"').size).to eq(8)
        expect(YAML.load_file(File.join(@source, '_link_previews/links.yml')).keys).to contain_exactly(
          "#{@base}/page?a=1&b=2", "#{@base}/og", "#{@base}/latin1", "#{@base}/meta-charset?x=1&y=2",
          "#{@base}/long-title",
          "#{@base}/page" # from index.html
        )
      end

      it 'does not fetch or cache links built by the page' do
        build_post
        expect(@requests).not_to include('/empty-title', '/untitled')
      end

      it 'does not mistake a generated URL for a longer literal URL that starts with it' do
        build_post
        expect(@requests).not_to include('/long')
        expect(@log.string).to include("Link preview: post.md links to #{@base}/long, which the page generates")
      end

      it 'shows the URL without a favicon and warns on every build when a generated link has no title' do
        2.times { build_post }
        expect(@log.string.scan(
          "Link preview: post.md links to #{@base}/empty-title, which the page generates; " \
          'give the link an inline title, e.g. [text](url "Title") in Markdown, ' \
          'or a title attribute in the layout or include that generates it'
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

      it 'neither fetches nor warns about the fragments of links built by the page' do
        File.write(File.join(@source, 'fragments.md'), <<~MARKDOWN)
          ---
          layout: post
          ---
          An [element]({{ site.generated }}/sections#intro "Element")
          and a [quote]({{ site.generated }}/sections#:~:text=quick,fox "Quote").
        MARKDOWN
        build_post
        output = Nokogiri::HTML5(File.read(File.join(@dir, '_site/fragments.html')))
        element, quote = %w[element quote].map do |text|
          link = output.css('article a').find { |a| a.text == text }
          Nokogiri::HTML5.fragment(link['data-bs-content'])
        end
        expect(element.at_css('a').text).to eq('Element')
        expect(element.at_css('blockquote')).to be_nil
        expect(quote.at_css('a').text).to eq('Quote')
        expect(quote.at_css('blockquote').text).to eq('quick … fox')
        expect(@requests).not_to include('/sections')
        expect(@log.string).not_to include('/sections')
      end

      it 'shows and publishes the favicon named by a generated link, removing the attribute' do
        FileUtils.mkdir_p(File.join(@source, '_link_previews/favicons'))
        File.binwrite(File.join(@source, '_link_previews/favicons/inline.png'), png_bytes)
        File.write(File.join(@source, 'iconic.html'), <<~HTML)
          ---
          layout: post
          ---
          <a href="{{ site.generated }}/untitled" title="Iconic" data-preview-favicon="inline.png">iconic</a>
        HTML
        build_post
        output = File.read(File.join(@dir, '_site/iconic.html'))
        expect(output).to include(
          %(data-bs-content="&lt;img class=&quot;link-preview-favicon&quot; src=&quot;/assets/img/favicons/inline.png&quot; alt=&quot;&quot;&gt;) +
          %(&lt;a href=&quot;#{@base}/untitled&quot; target=&quot;_blank&quot; rel=&quot;noopener&quot;&gt;Iconic&lt;/a&gt;" ) +
          %(data-favicon="/assets/img/favicons/inline.png">iconic</a>)
        )
        expect(output).not_to include('data-preview-favicon')
        expect(File.binread(File.join(@dir, '_site/assets/img/favicons/inline.png'))).to eq(png_bytes)
        expect(@requests).not_to include('/untitled')
      end
    end

    describe 'internal links' do
      before do
        FileUtils.mkdir_p(File.join(@source, '_layouts'))
        File.write(File.join(@source, '_layouts/titled.html'), <<~HTML)
          <html><head><title>{{ page.title }} &amp; Co</title></head><body><article>{{ content }}</article></body></html>
        HTML
        File.write(File.join(@source, 'index.html'), "---\n---\n<p>Index</p>\n")
        File.write(File.join(@source, 'target.md'), <<~MARKDOWN)
          ---
          layout: titled
          title: Target
          permalink: /target/
          ---
          Target

          ## The Section

          <p id="aside">An aside about the quick <em>brown</em> fox.</p>

          The quick red fox naps.
        MARKDOWN
        File.write(File.join(@source, 'plain.md'), "---\nlayout: titled\ntitle: Plain\npermalink: /plain\n---\nPlain\n")
        File.write(File.join(@source, 'untitled.html'), "---\n---\n<p>No head</p>\n")
        File.write(File.join(@source, 'generic.md'), "---\nlayout: titled\npermalink: /generic/\n---\nGeneric\n")
        FileUtils.mkdir_p(File.join(@source, 'files'))
        File.write(File.join(@source, 'files/paper.pdf'), '%PDF-1.4 fake')
        File.write(File.join(@source, 'files/café menu.pdf'), '%PDF-1.4 fake')
        FileUtils.mkdir_p(File.join(@source, '_link_previews/favicons'))
        File.binwrite(File.join(@source, '_link_previews/favicons/inline.png'), png_bytes)
      end

      def write_post(markdown, name: 'post.md')
        File.write(File.join(@source, name), "---\nlayout: titled\ntitle: Post\npermalink: /notes/post/\n---\n#{markdown}")
      end

      def build_site(config = {})
        config = Jekyll.configuration(
          { 'source' => @source, 'destination' => File.join(@dir, '_site'), 'url' => 'http://example.com' }.merge(config)
        )
        Jekyll::Site.new(config).process
        File.read(File.join(@dir, '_site/notes/post/index.html'))
      end

      def links_named(output, text)
        Nokogiri::HTML5(output).css('article a').select { |link| link.text == text }
      end

      def link_named(output, text)
        links = links_named(output, text)
        expect(links.size).to eq(1)
        links.first
      end

      def popover_link(link)
        Nokogiri::HTML5.fragment(link['data-bs-content']).at_css('a')
      end

      def popover_favicon(link)
        Nokogiri::HTML5.fragment(link['data-bs-content']).at_css('img')&.[]('src')
      end

      def links_yml
        YAML.load_file(File.join(@source, '_link_previews/links.yml'))
      end

      it "previews a link to another page with that page's title and the site's favicon, in the same tab" do
        write_post("A [link](/target/).\n")
        output = build_site
        expect(output).to include(
          %(<a href="/target/" class="link-preview" ) +
          %(data-bs-content="&lt;img class=&quot;link-preview-favicon&quot; src=&quot;/favicon.png&quot; alt=&quot;&quot;&gt;) +
          %(&lt;a href=&quot;/target/&quot;&gt;Target &amp;amp; Co&lt;/a&gt;" data-favicon="/favicon.png">link</a>)
        )
        expect(@log.string).not_to include('Link preview:')
        expect(links_yml).to be_empty
      end

      it 'resolves relative, index.html, extensionless, fragment, and query links to the page they name' do
        write_post(<<~MARKDOWN)
          [relative](../../target/) [dot](./../../target/) [index](/target/index.html) [unslashed](/target)
          [fragment](/target/#the-section) [query](/target/?q=1) [plain](/plain) [plain.html](../../plain.html)
        MARKDOWN
        output = build_site
        titles = %w[relative dot index unslashed fragment query plain plain.html].map do |text|
          popover_link(link_named(output, text)).text
        end
        expect(titles).to eq(['Target & Co'] * 4 + ['Target & Co # The Section', 'Target & Co'] + ['Plain & Co'] * 2)
        expect(@log.string).not_to include('Link preview:')
      end

      it 'leaves links to the page they are on untouched, however they name it' do
        write_post(<<~MARKDOWN)
          [section](#section) [page]() [query](?q=1#section) [path](/notes/post/) [index](/notes/post/index.html#section)
          [relative](../post/#section) [dot](./) [quote](#:~:text=nowhere)
        MARKDOWN
        output = build_site
        %w[section page query path index relative dot quote].each do |text|
          link = link_named(output, text)
          expect(link.attributes.keys).to eq(['href']), "#{text}: #{link.to_html}"
        end
        expect(@log.string).not_to include('Link preview:')
      end

      describe 'fragments' do
        def popover_quote(link)
          Nokogiri::HTML5.fragment(link['data-bs-content']).at_css('blockquote.link-preview-quote')&.text
        end

        it 'appends the heading text or id that an element fragment names to the title, without caching it' do
          write_post("A [heading](/target/#the-section), an [aside](../../target/#aside), and a [gone](/target/#gone) one.\n")
          output = build_site
          expect(popover_link(link_named(output, 'heading')).text).to eq('Target & Co # The Section')
          expect(popover_link(link_named(output, 'aside')).text).to eq('Target & Co # aside')
          expect(popover_link(link_named(output, 'gone')).text).to eq('Target & Co # gone')
          expect(popover_quote(link_named(output, 'heading'))).to be_nil
          expect(@log.string.scan('Link preview:').size).to eq(1)
          expect(@log.string).to include(
            'Link preview: post.md links to /target/#gone, ' \
            'but an element with the id "gone" could not be found on the page it links to' + "\n"
          )
          expect(links_yml).to be_empty
        end

        it 'quotes the text that a text fragment names below the title, warning about text not on the page' do
          write_post(<<~MARKDOWN)
            A [quote](/target/#:~:text=quick%20brown), a [range](/target/#:~:text=quick,naps),
            a [chosen](/target/#:~:text=fox.%20The-,quick,fox,-naps) one, and a [missing](/target/#:~:text=purple,fox) one.
          MARKDOWN
          output = build_site
          expect(popover_link(link_named(output, 'quote')).text).to eq('Target & Co')
          expect(popover_quote(link_named(output, 'quote'))).to eq('quick brown')
          expect(popover_quote(link_named(output, 'range'))).to eq('quick brown fox. The quick red fox naps')
          expect(popover_quote(link_named(output, 'chosen'))).to eq('quick red fox')
          expect(popover_quote(link_named(output, 'missing'))).to eq('purple … fox')
          expect(@log.string.scan('Link preview:').size).to eq(1)
          expect(@log.string).to include(
            'Link preview: post.md links to /target/#:~:text=purple,fox, ' \
            'but the text it quotes could not be found on the page it links to' + "\n"
          )
          expect(links_yml).to be_empty
        end

        it 'shows an inline title in place of the whole title, still quoting text' do
          write_post(%([titled](/target/#the-section "Inline") and [titled quote](/target/#:~:text=naps "Inline").\n))
          output = build_site
          expect(popover_link(link_named(output, 'titled')).text).to eq('Inline')
          expect(popover_link(link_named(output, 'titled quote')).text).to eq('Inline')
          expect(popover_quote(link_named(output, 'titled quote'))).to eq('naps')
        end
      end

      it 'leaves footnote references and back-references to the footnotes script' do
        write_post("A claim[^1] and a [link](/target/).\n\n[^1]: A note.\n")
        output = build_site
        expect(output).to include('<a href="#fn:1" class="footnote" rel="footnote">1</a>')
        expect(output).to include('<a href="#fnref:1" class="reversefootnote" role="doc-backlink">&#8617;</a>')
        expect(output.scan('class="link-preview"').size).to eq(1)
      end

      it 'does not need an inline title for an internal link the page generates' do
        write_post(%(A [generated]({{ "/target/" | relative_url }}).\n))
        output = build_site
        expect(popover_link(link_named(output, 'generated')).text).to eq('Target & Co')
        expect(@log.string).not_to include('Link preview:')
      end

      it 'uses an internal link\'s own title and favicon instead of its target\'s' do
        write_post(%([titled](/target/ "Inline") <a href="/target/" data-preview-favicon="inline.png">iconic</a>\n))
        output = build_site
        expect(popover_link(link_named(output, 'titled')).text).to eq('Inline')
        expect(popover_favicon(link_named(output, 'titled'))).to eq('/favicon.png')
        iconic = link_named(output, 'iconic')
        expect(popover_link(iconic).text).to eq('Target & Co')
        expect(popover_favicon(iconic)).to eq('/assets/img/favicons/inline.png')
        expect(iconic['data-favicon']).to eq('/assets/img/favicons/inline.png')
        expect(File.binread(File.join(@dir, '_site/assets/img/favicons/inline.png'))).to eq(png_bytes)
      end

      it 'shows the URL and warns when the linked page has no title' do
        write_post("An [untitled](/untitled.html) page.\n")
        output = build_site
        expect(popover_link(link_named(output, 'untitled')).text).to eq('/untitled.html')
        expect(@log.string).to include(
          'Link preview: post.md links to /untitled.html, which has no title; give the page a <title>, ' \
          'or give the link an inline title, e.g. [text](url "Title") in Markdown'
        )
      end

      it 'treats a linked page with no title in its front matter as having no title, whatever its <title>' do
        write_post("A [generic](/generic/) page and a [titled](/generic/ \"Inline\") link to it.\n")
        output = build_site
        expect(popover_link(link_named(output, 'generic')).text).to eq('/generic/')
        expect(popover_link(link_named(output, 'titled')).text).to eq('Inline')
        expect(@log.string.scan('Link preview:')).to eq(['Link preview:'])
        expect(@log.string).to include(
          'Link preview: post.md links to /generic/, which has no title; give the page a <title>, ' \
          'or give the link an inline title, e.g. [text](url "Title") in Markdown'
        )
      end

      it 'previews a link to an HTML file without front matter with its own <title>' do
        File.write(File.join(@source, 'static.html'), "<html><head><title>Static &amp; Plain</title></head></html>\n")
        write_post("A [static](/static.html) page.\n")
        output = build_site
        expect(popover_link(link_named(output, 'static')).text).to eq('Static & Plain')
        expect(@log.string).not_to include('Link preview:')
      end

      it 'records links to files other than pages in the cache, without a title, for filling in by hand' do
        write_post(<<~MARKDOWN)
          A [paper](/files/paper.pdf), [again](../../files/paper.pdf#page=2), a [menu](/files/café%20menu.pdf),
          [the same menu](</files/caf%C3%A9 menu.pdf>), and the [feed](/feed.xml).
        MARKDOWN
        output = build_site
        expect(links_yml).to include(
          '/files/paper.pdf' => { 'title' => nil, 'error' => 'not HTML (application/pdf)' },
          '/files/café menu.pdf' => { 'title' => nil, 'error' => 'not HTML (application/pdf)' },
          '/feed.xml' => { 'title' => nil, 'error' => 'not HTML (text/xml)' }
        )
        paper = link_named(output, 'paper')
        expect(popover_link(paper).text).to eq('/files/paper.pdf')
        expect(popover_favicon(paper)).to eq('/favicon.png')
        expect(@log.string.scan('Link preview: /files/paper.pdf: no title (not HTML (application/pdf)); ').size).to eq(1)
        expect(@requests).to be_empty
      end

      it 'uses hand-filled titles for files other than pages' do
        File.write(File.join(@source, '_link_previews/links.yml'), "/files/paper.pdf:\n  title: A Paper\n")
        write_post("A [paper](/files/paper.pdf).\n")
        output = build_site
        expect(popover_link(link_named(output, 'paper')).text).to eq('A Paper')
        expect(popover_favicon(link_named(output, 'paper'))).to eq('/favicon.png')
        expect(@log.string).not_to include('/files/paper.pdf')
      end

      it 'fails the build on a link to something that is not in the site, naming the page and link' do
        ['/nowhere/', 'nowhere.pdf', '/files/', '/target/missing.html'].each do |href|
          write_post("A [broken link](#{href}).\n")
          expect { build_site }.to raise_error(
            Jekyll::LinkPreviews::BrokenLinkError, "post.md links to #{href}, which is not in the site"
          )
        end
      end

      it 'fails the build on a link that cannot be parsed, naming the page and link' do
        ['/a|b/', '/a{b}/', 'a\\b'].each do |href|
          write_post(%(An <a href="#{href}">unparseable link</a>.\n))
          expect { build_site }.to raise_error(
            Jekyll::LinkPreviews::BrokenLinkError, "post.md links to #{href}, which cannot be parsed as a URL"
          )
        end
      end

      it 'does not preview other schemes or links outside articles' do
        write_post(<<~MARKDOWN)
          [mail](mailto:blog@numist.net) [phone](tel:+15555550100) <a href="javascript:void(0)">script</a>
        MARKDOWN
        File.write(File.join(@source, 'index.html'), "---\n---\n<footer><a href=\"/nowhere/\">footer</a></footer>\n")
        output = build_site
        expect(output).not_to include('link-preview')
        expect(File.read(File.join(@dir, '_site/index.html'))).to include('<footer><a href="/nowhere/">footer</a></footer>')
      end

      describe 'with a baseurl' do
        it 'resolves links within the baseurl and uses its favicon' do
          write_post("An [absolute](/blog/target/) and a [relative](../../target/) link.\n")
          output = build_site('baseurl' => '/blog')
          %w[absolute relative].each do |text|
            link = link_named(output, text)
            expect(popover_link(link).text).to eq('Target & Co')
            expect(popover_favicon(link)).to eq('/blog/favicon.png')
          end
        end

        it 'keys files by their URL within the baseurl' do
          write_post("A [paper](/blog/files/paper.pdf).\n")
          build_site('baseurl' => '/blog')
          expect(links_yml).to include('/blog/files/paper.pdf' => { 'title' => nil, 'error' => 'not HTML (application/pdf)' })
        end

        it 'fails on links outside the baseurl' do
          write_post("A [broken link](/target/).\n")
          expect { build_site('baseurl' => '/blog') }.to raise_error(
            Jekyll::LinkPreviews::BrokenLinkError, 'post.md links to /target/, which is not in the site'
          )
        end
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

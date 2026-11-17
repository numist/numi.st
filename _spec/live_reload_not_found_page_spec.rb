# ABOUTME: Specs for serving the site's 404 page with the LiveReload script under `jekyll serve --livereload`,
# ABOUTME: run against Jekyll's own servlet in a local WEBrick server, and for the plugin activating only then.
require 'rspec'
require 'jekyll'
require 'tmpdir'
require 'fileutils'
require 'open3'
require 'rbconfig'
require 'net/http'
require_relative '../_plugins/live_reload_not_found_page'

describe 'the LiveReload 404 page' do
  let(:live_reload_script) { 'livereload.js' }

  def get(path, livereload:)
    Dir.mktmpdir do |source|
      dir = File.join(source, '_site')
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, 'index.html'), "<html><head><title>Home</title></head><body>Home</body></html>\n")
      File.write(File.join(dir, '404.html'), "<html><head><title>Lost</title></head><body>Not here</body></html>\n")
      site = Jekyll::Site.new(Jekyll.configuration(
        'source' => source, 'destination' => dir, 'quiet' => true,
        'serving' => true, 'livereload' => livereload, 'livereload_port' => 35_729
      ))
      Jekyll::Commands::Serve.send(:setup, dir)
      server = WEBrick::HTTPServer.new(
        BindAddress: '127.0.0.1', Port: 0, DocumentRoot: dir, JekyllOptions: site.config,
        MimeTypesCharset: Jekyll::Commands::Serve.send(:mime_types_charset),
        Logger: WEBrick::Log.new(File::NULL), AccessLog: []
      ).tap { |s| s.unmount('') }
      server.mount('', Jekyll::Commands::Serve::Servlet, dir, WEBrick::Config::FileHandler)
      thread = Thread.new { server.start }
      begin
        Net::HTTP.get_response(URI("http://127.0.0.1:#{server.config[:Port]}#{path}"))
      ensure
        server.shutdown
        thread.join
      end
    end
  end

  # Sets up a site with the plugin in a fresh Ruby, reporting whether that loaded WEBrick and patched the servlet.
  def setting_up_site(config)
    script = <<~RUBY
      require 'jekyll'
      require 'tmpdir'
      require #{File.expand_path('../_plugins/live_reload_not_found_page', __dir__).inspect}
      Dir.mktmpdir do |dir|
        Jekyll::Site.new(Jekyll.configuration(#{config.inspect}.merge('source' => dir, 'destination' => File.join(dir, '_site'), 'quiet' => true)))
      end
      patched = defined?(Jekyll::Commands::Serve::Servlet) &&
                Jekyll::Commands::Serve::Servlet.include?(Jekyll::LiveReloadNotFoundPage)
      print [defined?(WEBrick) && 'loads WEBrick', patched && 'patches the servlet'].select(&:itself).join(', ')
    RUBY
    output, status = Open3.capture2e(RbConfig.ruby, '-e', script)
    raise output unless status.success?

    output
  end

  it 'serves a missing path as the 404 page with the LiveReload script' do
    response = get('/nope', livereload: true)
    expect(response.code).to eq('404')
    expect(response.body).to include('Not here')
    expect(response.body.scan(live_reload_script).size).to eq(1)
  end

  it 'serves an existing page with the LiveReload script once' do
    response = get('/', livereload: true)
    expect(response.code).to eq('200')
    expect(response.body).to include('Home')
    expect(response.body.scan(live_reload_script).size).to eq(1)
  end

  it 'serves a missing path as the 404 page without the script when LiveReload is off' do
    response = get('/nope', livereload: false)
    expect(response.code).to eq('404')
    expect(response.body).to include('Not here')
    expect(response.body).not_to include(live_reload_script)
  end

  it 'loads WEBrick and patches the servlet only when the site is served with LiveReload' do
    expect(setting_up_site({})).to eq('')
    expect(setting_up_site('serving' => true)).to eq('')
    expect(setting_up_site('serving' => true, 'livereload' => true)).to eq('loads WEBrick, patches the servlet')
  end
end

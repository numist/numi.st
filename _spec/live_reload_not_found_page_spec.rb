# ABOUTME: Specs for serving the site's 404 page with the LiveReload script under `jekyll serve --livereload`,
# ABOUTME: run against Jekyll's own servlet in a local WEBrick server, and for the plugin activating only then.
require 'rspec'
require 'jekyll'
require 'tmpdir'
require 'fileutils'
require 'open3'
require 'rbconfig'
require 'net/http'
require 'jekyll/commands/serve/servlet'
require_relative '../_plugins/live_reload_not_found_page'

describe 'the LiveReload 404 page' do
  let(:live_reload_script) { 'livereload.js' }

  def request(method, path, livereload:)
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
        Net::HTTP.start('127.0.0.1', server.config[:Port]) { |http| http.send_request(method, path) }
      ensure
        server.shutdown
        thread.join
      end
    end
  end

  # Sets up a site with the plugin in a fresh Ruby, reporting whether that patched Jekyll's servlet.
  def patches_servlet?(config)
    script = <<~RUBY
      require 'jekyll'
      require 'tmpdir'
      require #{File.expand_path('../_plugins/live_reload_not_found_page', __dir__).inspect}
      Dir.mktmpdir do |dir|
        Jekyll::Site.new(Jekyll.configuration(#{config.inspect}.merge('source' => dir, 'destination' => File.join(dir, '_site'), 'quiet' => true)))
      end
      patched = defined?(Jekyll::Commands::Serve::Servlet) &&
                Jekyll::Commands::Serve::Servlet.include?(Jekyll::LiveReloadNotFoundPage)
      print patched ? 'patched' : 'unpatched'
    RUBY
    output, status = Open3.capture2e(RbConfig.ruby, '-e', script)
    raise output unless status.success?

    output == 'patched'
  end

  it 'serves a missing path as the 404 page with the LiveReload script' do
    response = request('GET', '/nope', livereload: true)
    expect(response.code).to eq('404')
    expect(response.body).to include('Not here')
    expect(response.body.scan(live_reload_script).size).to eq(1)
  end

  it 'serves an existing page with the LiveReload script once' do
    response = request('GET', '/', livereload: true)
    expect(response.code).to eq('200')
    expect(response.body).to include('Home')
    expect(response.body.scan(live_reload_script).size).to eq(1)
  end

  it 'serves a missing path as the 404 page without the script when LiveReload is off' do
    Jekyll::Commands::Serve::Servlet.include(Jekyll::LiveReloadNotFoundPage)
    response = request('GET', '/nope', livereload: false)
    expect(response.code).to eq('404')
    expect(response.body).to include('Not here')
    expect(response.body).not_to include(live_reload_script)
  end

  it 'answers a HEAD request for a missing path with 404 and no body' do
    response = request('HEAD', '/nope', livereload: true)
    expect(response.code).to eq('404')
    expect(response.body).to be_nil
  end

  it 'patches the servlet only when the site is served with LiveReload' do
    expect(patches_servlet?({})).to be(false)
    expect(patches_servlet?('serving' => true)).to be(false)
    expect(patches_servlet?('serving' => true, 'livereload' => true)).to be(true)
  end
end

# ABOUTME: Specs for the site's <head> include, rendered in a scratch site alongside jekyll-seo-tag,
# ABOUTME: covering the page title that browsers and link previews show.
require 'rspec'
require 'jekyll'
require 'tmpdir'
require 'fileutils'

describe '_includes/head.html' do
  def titles_of(pages)
    Dir.mktmpdir do |dir|
      source = File.join(dir, 'source')
      FileUtils.mkdir_p(File.join(source, '_includes'))
      FileUtils.mkdir_p(File.join(source, '_layouts'))
      FileUtils.cp(File.expand_path('../_includes/head.html', __dir__), File.join(source, '_includes'))
      File.write(File.join(source, '_layouts/default.html'), "<html>{% include head.html %}<body>{{ content }}</body></html>\n")
      pages.each do |name, front_matter|
        File.write(File.join(source, name), "#{front_matter.merge('layout' => 'default').to_yaml}---\nBody\n")
      end
      destination = File.join(dir, '_site')
      Jekyll::Site.new(Jekyll.configuration(
        'source' => source, 'destination' => destination, 'quiet' => true,
        'title' => 'numist log', 'plugins' => ['jekyll-seo-tag']
      )).process
      pages.keys.to_h do |name|
        html = File.read(File.join(destination, name.sub(/\.md\z/, '.html')))
        [name, html.scan(%r{<title>(.*?)</title>}m).flatten]
      end
    end
  end

  it "titles a page with its own title, without the site's" do
    expect(titles_of('code.md' => { 'title' => 'Code' })).to eq('code.md' => ['Code'])
  end

  it "titles an untitled page with the site's title" do
    expect(titles_of('untitled.md' => {})).to eq('untitled.md' => ['numist log'])
  end

  it "titles a page whose title has no text with the site's title" do
    expect(titles_of('blank.md' => { 'title' => '<br>' })).to eq('blank.md' => ['numist log'])
  end

  it 'titles a page with the plain text of its Markdown title' do
    expect(titles_of('misadventure.md' => { 'title' => "Scott's `misadventure` & co" }))
      .to eq('misadventure.md' => ['Scott’s misadventure &amp; co'])
  end
end

# ABOUTME: Specs for the inline_markdownify Liquid filter, which renders a line of Markdown, such as a
# ABOUTME: page's title, as inline HTML with typographic punctuation.
require 'rspec'
require 'jekyll'
require 'tmpdir'
require_relative '../_plugins/inline_markdownify'

describe Jekyll::InlineMarkdownifyFilter do
  def inline_markdownify(text)
    Dir.mktmpdir do |dir|
      site = Jekyll::Site.new(Jekyll.configuration('source' => dir, 'destination' => File.join(dir, '_site'), 'quiet' => true))
      Liquid::Template.parse('{{ text | inline_markdownify }}')
                      .render!({ 'text' => text }, registers: { site: site }, strict_filters: true)
    end
  end

  it 'renders Markdown as inline HTML, without a paragraph around it' do
    expect(inline_markdownify('*Fish* & `Chips`')).to eq(
      '<em>Fish</em> &amp; <code class="language-plaintext highlighter-rouge">Chips</code>'
    )
  end

  it 'makes punctuation typographic' do
    expect(inline_markdownify(%(Fish -- "Chips"...))).to eq('Fish – “Chips”…')
  end
end

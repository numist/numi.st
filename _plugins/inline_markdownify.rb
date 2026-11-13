# ABOUTME: A Liquid filter that renders a line of Markdown, such as a page's title, as inline HTML with
# ABOUTME: typographic punctuation: smartified and markdownified, without the paragraph around it.
require 'jekyll'

module Jekyll
  module InlineMarkdownifyFilter
    def inline_markdownify(input)
      strip(remove(remove(markdownify(smartify(input)), '<p>'), '</p>'))
    end
  end
end

Liquid::Template.register_filter(Jekyll::InlineMarkdownifyFilter)

require 'digest/md5'
require 'ruby-graphviz'

module Jekyll
  class GraphvizBlock < Liquid::Block
    def initialize(tag_name, markup, options)
      super
      @tag = markup
    end

    def render(context)
      graph = GraphViz.parse_string(super)

      graph_id = @tag unless @tag.empty?
      graph_id ||= graph.id if graph.id.match?(/^[a-zA-Z0-9]+$/)
      graph_id ||= Digest::MD5.hexdigest(super)

      svg = graph.output(:svg => String).
        gsub(' font-family="Times,serif"',          ' font-family="Museo"').
        gsub(' font-family="Courier,monospace"',    ' font-family="Fira Code"').
        gsub(' font-family="Helvetica,sans-Serif"', ' font-family="Fira Sans"').
        sub(/^.*?<svg/m,                            "<svg class=\"graphviz\" id=\"#{ graph_id }\"").
        sub(/<polygon fill="white" stroke="none" .*?>/m, '').
        gsub(/<!--.*?-->/m, '')

      "#{svg}"
    end
  end
end

Liquid::Template.register_tag('graphviz', Jekyll::GraphvizBlock)

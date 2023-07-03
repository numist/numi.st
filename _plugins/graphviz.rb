require 'digest/md5'
require 'ruby-graphviz'

module Jekyll
  class GraphvizBlock < Liquid::Block
    def initialize(tag_name, markup, options)
      super

      # extract id from markup, if set
      @graph_id = markup.split[0] if markup.split[0] && markup.split[0].match?(/^[a-zA-Z0-9]+$/)

      # extract matching width and height attributes, if any
      @width = markup.match(/(width="[\d]+pt")/)[1] if markup.match(/(width="[\d]+pt")/)
      @height = markup.match(/(height="[\d]+pt")/)[1] if markup.match(/(height="[\d]+pt")/)
    end

    def render(context)
      graph = GraphViz.parse_string(super)

      graph_id = @graph_id unless @graph_id.nil?
      graph_id ||= graph.id if graph.id.match?(/^[a-zA-Z0-9]+$/)
      graph_id ||= Digest::MD5.hexdigest(super)
      
      svg = graph.output(:svg => String).
        sub(/^.*<svg/m, "<svg class=\"graphviz\" id=\"#{ graph_id }\"").
        gsub(' font-family="Times,serif"', ' font-family="Museo"').
        gsub(' font-family="Courier,monospace"', ' font-family="Fira Code"').
        gsub(' font-family="Helvetica,sans-Serif"', ' font-family="Fira Sans"').
        gsub(/<!--.*?-->/m, '')

      # Replace the first instance of width and height attributes with the ones
      # specified in the tag, if any
      svg.sub!(/(width="[\d]+pt")/, @width) if @width
      svg.sub!(/(height="[\d]+pt")/, @height) if @height

      svg
    end
  end
end

Liquid::Template.register_tag('graphviz', Jekyll::GraphvizBlock)

require 'digest/md5'
require 'ruby-graphviz'

module Jekyll
  class GraphvizBlock < Liquid::Block
    def initialize(tag_name, markup, tokens)
      super
      @markup = markup.strip
    end

    def render(context)
      # Generate a unique ID for the rendered graph
      graph_id = Digest::MD5.hexdigest(super)

      # Parse the Graphviz DOT input
      graph = GraphViz.parse_string(super)
      raise "not a valid graph definition" unless graph

      # Render the graph as SVG output and add a unique ID to the <svg> element
      svg_output = graph.output(:svg => String).sub(/^.*<svg/m, "<svg id=\"graphviz-#{graph_id}\"")
      
      # Wrap the SVG in a <div> element with a class of "graphviz"
      "<div class=\"graphviz\">#{svg_output.to_s}</div>"
    end
  end
end

# Example usage:
#
# {% graphviz %}
# digraph {
#   A -> B -> C;
# }
# {% endgraphviz %}
Liquid::Template.register_tag('graphviz', Jekyll::GraphvizBlock)
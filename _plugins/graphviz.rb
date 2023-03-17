require 'ruby-graphviz'

module Jekyll
  class GraphvizBlock < Liquid::Block
    def initialize(tag_name, markup, options)
      super
      @tag = markup
    end

    def render(context)
      graph_src = super

      # Parse the Graphviz DOT input
      # raise "#{@tag}" unless @tag.empty?
      # raise "#{@options}" unless @options.nil?
      graph = GraphViz.parse_string(graph_src)
      raise "\"#{graph_src.lines.first.chomp}\" is not a valid graph definition" unless graph
      raise "graph is not named?" unless graph.id

      # Render the graph as SVG output and add a unique ID to the <svg> element
      svg_output = graph.output(:svg => String).sub(/^.*<svg/m, "<svg id=\"graphviz-#{ graph.id }\"")
      
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
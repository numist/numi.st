# Source: https://stackoverflow.com/questions/19169849/how-to-get-markdown-processed-content-in-jekyll-tag-plugin

module Jekyll
    module Tags
      class CalloutBlock < Liquid::Block
  
        def initialize(tag_name, type, tokens)
          super
          type.strip!
          if type.empty?
            @type = "default"
          elsif %w(info danger warning primary success default).include?(type)
            @type = type
          else
            raise "callout type \"#{type}\" not supported."
          end
        end
  
        def render(context)
          site = context.registers[:site]
          converter = site.find_converter_instance(::Jekyll::Converters::Markdown)
          output = converter.convert(super(context))
          "<div class=\"bd-callout bd-callout-#{@type}\">#{output}</div>"
        end
      end
    end
  end
  
  Liquid::Template.register_tag('callout', Jekyll::Tags::CalloutBlock)
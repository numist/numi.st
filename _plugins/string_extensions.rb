module Jekyll
    module StringFilter
      def ends_with(text, query)
        return text.end_with? query
      end

      def starts_with(text, query)
        return text.start_with? query
      end
    end
 end

 Liquid::Template.register_filter(Jekyll::StringFilter)
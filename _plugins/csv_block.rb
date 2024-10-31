require 'csv'

# Usage:
#
# {% csv %}
# Name, Age, Occupation
# Alice, 30, Engineer
# Bob, 25, Designer
# Charlie, 35, Teacher
# {% endcsv %}
#
# {% csv header:false %}
# Alice, 30, Engineer
# Bob, 25, Designer
# Charlie, 35, Teacher
# {% endcsv %}
#
# {% csv header:true separator:tab %}
# Name	Age	Occupation
# Alice	30	Engineer
# Bob	25	Designer
# Charlie	35	Teacher
# {% endcsv %}
#

module Jekyll
  class CSVBlock < Liquid::Block
    def initialize(tag_name, markup, tokens)
      super
      # Parse options from the markup (e.g., header: false, separator: tab)
      @options = {}
      markup.strip.split.each do |option|
        key, value = option.split(':')
        if key == 'header'
          @options[key] = value == 'false' ? false : true
        elsif key == 'separator'
          @options[key] = value == 'tab' ? "\t" : ','
        end
      end
    end

    def render(context)
      csv_text = super.strip
      has_headers = @options.fetch('header', true)
      separator = @options.fetch('separator', ',')

      # Parse CSV with or without headers and with the specified separator
      csv_data = CSV.parse(csv_text, headers: has_headers, col_sep: separator)

      # Start generating HTML
      html = "<table>\n"
      
      if has_headers
        # Generate header row
        html << "<thead>\n<tr>\n"
        csv_data.headers.each do |header|
          html << "<th>#{header}</th>"
        end
        html << "</tr>\n</thead>\n"
      end

      # Generate data rows
      html << "<tbody>\n"
      csv_data.each do |row|
        html << "<tr>"
        row = row.to_hash.values if has_headers
        row.each do |value|
          html << "<td>#{value}</td>"
        end
        html << "</tr>\n"
      end
      html << "</tbody>\n</table>\n"
      
      html
    end
  end
end

Liquid::Template.register_tag('csv', Jekyll::CSVBlock)

---
layout: page
title: "CSV Tables in Jekyll"
description: "For when the Markdown syntax is too annoying to work with."
published_at: Wed Oct 30 20:54:57 PDT 2024
---

Not that I'm using tables anywhere on this site, but I did some tabular-shaped stuff at work recently and it really made me appreciate the ubiquity of CSV data and tooling that understands me. Which immediately made me cranky about Markdown's table syntax, which is annoying to edit even among people who can remember its syntax.

So, for the sake of easing my soul by writing a gift to my future self:

``` ruby
# _plugins/csv_block.rb
require 'csv'

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
```

Usage:

``` liquid
{% raw %}{% csv %}
Name, Age, Occupation
Alice, 30, Engineer
Bob, 25, Designer
Charlie, 35, Teacher
{% endcsv %}

{% csv header:false %}
Alice, 30, Engineer
Bob, 25, Designer
Charlie, 35, Teacher
{% endcsv %}

{% csv header:true separator:tab %}
Name	Age	Occupation
Alice	30	Engineer
Bob	25	Designer
Charlie	35	Teacher
{% endcsv %}{% endraw %}
```

Output:

{% csv %}
Name, Age, Occupation
Alice, 30, Engineer
Bob, 25, Designer
Charlie, 35, Teacher
{% endcsv %}

{% csv header:false %}
Alice, 30, Engineer
Bob, 25, Designer
Charlie, 35, Teacher
{% endcsv %}

{% csv header:true separator:tab %}
Name	Age	Occupation
Alice	30	Engineer
Bob	25	Designer
Charlie	35	Teacher
{% endcsv %}

# _plugins/csv_block.rb
require 'jekyll'
require 'liquid'
require 'csv'
require 'dentaku'

module Jekyll
  class CSVBlock < ::Liquid::Block
    def initialize(tag_name, markup, tokens)
      super
      @options = {}
      markup.strip.split.each do |option|
        key, value = option.split(':')
        @options[key] = (value == 'false' ? false : true) if key == 'header'
        @options[key] = (value == 'tab' ? "\t" : ',') if key == 'separator'
      end
      @calculator = Dentaku::Calculator.new
    end

    def render(context)
      begin

        csv_text = super.strip
        has_headers = @options.fetch('header', true)
        separator = @options.fetch('separator', ',')

        # Parse CSV with or without headers
        csv_data = CSV.parse(csv_text, headers: has_headers, col_sep: separator)
        table_data = csv_data.map { |row| has_headers ? row.to_hash.values : row }
        headers = has_headers ? csv_data.headers : nil

        # Start generating HTML
        html = "<table>\n"
        
        if has_headers
          # Generate header row
          html << "<thead>\n<tr>\n"
          headers.each do |header|
            html << "<th>#{header.strip}</th>"
          end
          html << "</tr>\n</thead>\n"
        end

        # Generate data rows
        html << "<tbody>\n"
        evaluated_cells = {} # Cache for evaluated cells
        table_data.each_with_index do |row, row_index|
          html << "<tr>"
          row.each_with_index do |value, col_index|
            evaluated_value = evaluate_formula(value, table_data, row_index, col_index, headers, evaluated_cells, has_headers)
            html << "<td>#{evaluated_value}</td>"
          end
          html << "</tr>\n"
        end
        html << "</tbody>\n</table>\n"
        
        return html
      rescue => e
        return e.message
      end
    end

    private

    # Evaluate cell if it starts with '=' indicating a formula
    def evaluate_formula(value, table_data, current_row, current_col, headers, evaluated_cells, has_headers, visiting = Set.new)
      return value unless value.is_a?(String) && value.start_with?('=')

      cell_key = [current_row, current_col]
      return evaluated_cells[cell_key] if evaluated_cells.key?(cell_key)

      # Detect circular dependencies
      if visiting.include?(cell_key)
        return "Error: Circular Reference at cell #{cell_key}"
      else
        visiting.add(cell_key)
      end

      formula = value[1..-1].strip # Remove '=' from start of formula

      begin
        # Replace cell references with values
        formula_with_values = formula.gsub(/([A-Z]+)(\d+)/i) do |match|
          row_index, col_index = parse_cell_reference(match, headers, has_headers)
          referenced_value = table_data.dig(row_index, col_index)
          return "Error: Out of Bounds reference #{match} at row #{row_index}, col #{col_index}" if referenced_value.nil?

          # Recursively evaluate referenced cell if it's a formula
          evaluate_formula(referenced_value, table_data, row_index, col_index, headers, evaluated_cells, has_headers, visiting)
        end

        # Evaluate using Dentaku
        evaluated_result = @calculator.evaluate(formula_with_values) || value
      rescue => e
        return "Error: Formula Evaluation in cell #{cell_key} - #{e.message}"
      ensure
        visiting.delete(cell_key)
      end

      evaluated_cells[cell_key] = evaluated_result
      evaluated_result
    end

    def parse_cell_reference(ref, headers, has_headers)
      col_letter, row_number = ref.match(/([A-Z]+)(\d+)/i).captures
      row_index = row_number.to_i - 1
      col_index = has_headers ? headers.index(col_letter.upcase) : col_letter.ord - 'A'.ord
      return "Error: Invalid Column Reference #{col_letter}" if col_index.nil?

      [row_index, col_index]
    end
  end
end

Liquid::Template.register_tag('csv', Jekyll::CSVBlock)

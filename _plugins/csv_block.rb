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
      @evaluation_cache = {}
    end

    def render(context)
      begin

        csv_text = super.strip
        has_headers = @options.fetch('header', true)
        separator = @options.fetch('separator', ',')

        # Parse CSV with or without headers
        csv_data = CSV.parse(csv_text, headers: has_headers, col_sep: separator)
        if has_headers
          table_data = [csv_data.headers] + csv_data.map(&:to_hash).map(&:values)
        else
          table_data = csv_data
        end

        # Start generating HTML
        html = "<table>\n"
        
        if has_headers
          # Generate header row
          html << "<thead>\n<tr>\n"
          table_data.first.each_with_index do |header, col_index|
            html << "<th>#{evaluate_formula_at_index(col_index, 0, table_data)}</th>"
          end
          html << "</tr>\n</thead>\n"
        end

        # Generate data rows
        html << "<tbody>\n"
        table_data.each_with_index do |row, row_index|
          next if row_index == 0 and has_headers
          html << "<tr>"
          row.each_with_index do |value, col_index|
            evaluated_value = evaluate_formula_at_index(col_index, row_index, table_data)
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

    # Conversion functions between spreadsheet style ("val") and zero-based coordinates ("index")
    def col_index_to_val(col_index)
      (col_index + 'A'.ord).chr
    end
    def col_val_to_index(col_val)
      if col_val.length == 1
        col_val.ord - 'A'.ord
      else
        base = 'Z'.ord - 'A'.ord + 1
        col_val.chars.reduce(0) { |result, char| result * base + char.ord - 'A'.ord + 1 } - 1
      end
    end
    def row_index_to_val(row_index)
      row_index + 1
    end
    def row_val_to_index(row_val)
      row_val - 1
    end

    def evaluate_formula_at_index(col_index, row_index, table_data, visiting = Set.new)
      begin
        evaluate_formula_at_index_internal(col_index, row_index, table_data, visiting)
      rescue => e
        e.message
      end
    end

    def evaluate_formula_at_index_internal(col_index, row_index, table_data, visiting)
      value = table_data[row_index][col_index].strip
      return value unless value.is_a?(String) && value.start_with?('=')

      # Return results out of cache, if possible
      cell_key = [col_index, row_index]
      return @evaluation_cache[cell_key] if @evaluation_cache.key?(cell_key)

      # puts "evaluate_formula: #{col_index_to_val(col_index)}#{row_index_to_val(row_index)}: #{value}"

      # Detect circular dependencies
      if visiting.include?(cell_key)
        raise "Error: circular reference: #{visiting.to_a.map { |key| "#{col_index_to_val(key[0])}#{row_index_to_val(key[1])}" }.sort.join(', ')}"
      else
        visiting.add(cell_key)
      end

      # Remove '=' from start of formula
      formula = value[1..-1].strip

      # Identify cell references and replace with values
      formula_with_values = formula.gsub(/([A-Z]+)(\d+)(:([A-Z]+)(\d+))?/i) do |match|
        if $3
          start_col, start_row, end_col, end_row = $1, $2.to_i, $4, $5.to_i
          start_col_index = col_val_to_index(start_col)
          start_row_index = row_val_to_index(start_row)
          end_col_index = col_val_to_index(end_col)
          end_row_index = row_val_to_index(end_row)

          # Check if the range is valid
          if start_col_index.nil? || start_row_index.nil? || end_col_index.nil? || end_row_index.nil? \
          || start_col_index > end_col_index || start_row_index > end_row_index \
          || end_col_index >= table_data.first.length || end_row_index >= table_data.length
            raise "Error: #{col_index_to_val(col_index)}#{row_index_to_val(row_index)} references invalid range #{match}"
          end

          # Evaluate each cell in the range
          range_values = []
          (start_row_index..end_row_index).each do |row_index|
            (start_col_index..end_col_index).each do |col_index|
        range_values << evaluate_formula_at_index_internal(col_index, row_index, table_data, visiting)
            end
          end

          # Join the range values with a comma
          range_values.join(',')
        else
          ref_row_index = row_val_to_index($2.to_i)
          ref_col_index = col_val_to_index($1)
          referenced_value = table_data.dig(ref_row_index, ref_col_index)
          raise "Error: #{col_index_to_val(col_index)}#{row_index_to_val(row_index)} references invalid cell #{match}" if referenced_value.nil?

          # Recursively evaluate referenced cell if it's a formula
          evaluate_formula_at_index_internal(ref_col_index, ref_row_index, table_data, visiting)
        end
      end

      # Evaluate using Dentaku
      evaluated_result = @calculator.evaluate(formula_with_values) or raise "Error: #{col_index_to_val(col_index)}#{row_index_to_val(row_index)} uses invalid formula: #{formula}"

      @evaluation_cache[cell_key] = evaluated_result
      evaluated_result
    end
  end
end

Liquid::Template.register_tag('csv', Jekyll::CSVBlock)

# # _plugins/tablature_block.rb
# require 'jekyll'
# require 'liquid'

# module Jekyll
#   class TablatureBlock < ::Liquid::Block
#     def initialize(tag_name, markup, tokens)
#       super
#       @options = {}
#       markup.strip.split.each do |option|
#         key, value = option.split(':')
#         @options[key] = value if key == 'scale'
#         # @options[key] = (value == 'tab' ? "\t" : ',') if key == 'separator'
#       end
#     end
    
#     def render(context)
#       # Iterate over the lines in the block
#       lines = super.split("\n")
#       strings = 0
#       i = 0
      
#       html = "<figure class='tablature'>\n"
      
#       while i < lines.length
#         begin
#           next unless is_bar_line?(lines[i])
          
# # Exact details vary so this parser must be permissive, but generally bar lines have a format like:
# #
# # |----------------------------------|----------------------------------|
# # |----------------------------------|----------------------------------|
# # |------7--9---9--9-9\7-------------|--7---7----7----------------------|
# # |--7-9----9---9--9-9\7-------------|--7---7--9---9--------------------|
# # |----------------------------------|----------------------------------|
# # |----------------------------------|----------------------------------|
# #
# # The number of strings in the tablature block is the number of lines with aligned `|` characters
# # The number of strings in the tablature block must be consistent across all bars in the block
# # The number of strings in the tablature block must be consistent with the number of strings in the scale
# #
# # The parser identifies blocks and then iterates over pairs of `|` character indexes across the block's strings
# # emitting a <div class="bar"> element for each pair of indexes containing <div class="fret"> elements for each
# # sequence of non-`-` characters containing any numbers between the indexes. Character sequences that do not include
# # numbers are ignored. The parser will raise an error if the number of strings in the block is inconsistent.
# #
# # Fret divs are positioned within the bar using CSS grid. The rendered grid has 100 columns and `strings` rows.
# # The difference between the indexes of the `|` characters in a pair is the number of columns spanned by the bar.
# # A fret's position in the grid is determined by its centered position between the `|` characters of the bar.
# # In the example above, the first fret (7) of the first bar would be positioned at column 7 (2.5*100/34) and
# # the slides (9\7) would be positioned at column 56 (19*100/34).
# #

#           strings_in_bar = number_of_strings(lines, i)
#           if strings != 0 && strings != strings_in_bar
#             if is_bar_line?(lines[i + strings]) raise "Bar boundaries on line #{i + strings + 1} do not match preceding lines"
#             raise "Inconsistent number of strings in tablature block in bar starting at line #{i + 1}"
#           end
#           if is_bar_line?(lines[i + strings]) raise "Inconsistent number of strings in tablature block in bar starting at line #{i + 1}"

#           strings = number_of_strings(lines, i)

#           bar_boundaries = bar_indexes(lines[i])
#           bars = []
#           for j in 0..bar_boundaries.length - 2
#             bars << lines[i..i + strings - 1].map { |line| line[bar_boundaries[j]..bar_boundaries[j+1]] }
#           end

#           for j in 0..bars.length - 1
#             html << "\t<div class=\"bar\">\n"

#             for k in 0..strings - 1
#               fret_positions = []
#               bar.scan(/[^-]+/) do |fret|
#                 fret_positions << [fret, Regexp.last_match.begin(0)]
#               end
              
#               fret_positions.each do |fret, fret_start|
#                 position = (fret_start + fret.length / 2) * 100 / bar.length
#                 html << "\t\t<div class=\"fret\" style=\"grid-row: #{k + 1}\">#{fret}</div>\n"
#               end
#             end

#             html << "\t</div>\n"
#           end
          
#           i += strings
#         rescue => e
#           return error(e.message)
#         ensure
#           i += 1
#         end
#       end
      
#       html << "</figure>\n"
#     end
    
#     private
    
#     def is_bar_line?(line)
#       return false if line.start_with?('#') # Ignore comments
#       return false if line.strip.empty? # Ignore empty lines
#       return line.match?(/\|[^s]*[-][^s]*\|/)
#     end
    
#     def bar_indexes(line)
#       (0...first_line.length).find_all { |i| first_line[i] == '|' }
#     end
    
#     def number_of_strings(lines, start_line)
#       # Find the indexes of all instances of | in the first line
#       first_line = lines[start_line]
#       indexes = bar_indexes(first_line)
      
#       # The number of strings is 1 + the number of following lines with | characters at the same positions
#       strings = 1
#       while true
#         next_line = lines[start_line + strings]
#         break if next_line.nil?
#         break if indexes.none? { |i| next_line[i] == '|' }
#         strings += 1
#       end
      
#       return strings
#     end

#     def error(message)
#       message
#     end
#   end
  
#   Liquid::Template.register_tag('tablature', Jekyll::TablatureBlock)
  
#! /usr/bin/env ruby

@scale = 0.75

def print_x_label(x, name)
  puts "  \"a[#{x}]\" [pos=\"#{(0.5+x.to_f)*@scale},0.15!\",label=\"#{name}\"]"
end
def print_y_label(y, name)
  puts "  \"b[#{y}]\" [pos=\"-0.15,-#{(0.5+y.to_f)*@scale}!\",label=\"#{name}\"]"
end

def print_node(x, y)
  puts "  \"#{x}_#{y}\" [pos=\"#{x.to_f*@scale},-#{y.to_f*@scale}!\"]"
end

def print_edge(from, to, comment)
  puts "  \"#{from}\" -> \"#{to}\" [id=\"edge_#{from}to#{to}\"] /* \"#{comment}\" */"
end

def print_char_pairs(str1, str2)
  # Labels
  str1.each_char.with_index do |char1, i|
    print_x_label(i, char1)
  end
  puts "\n"

  str2.each_char.with_index do |char2, j|
    print_y_label(j, char2)
  end
  puts "\n"
  
  # Nodes
  puts "  node [shape=point,fixedsize=true]\n\n"
  str1.each_char.with_index do |char1, i|
    str2.each_char.with_index do |char2, j|
      print_node(i, j)
    end
    print_node(i, str2.length)
  end
  str2.each_char.with_index do |char2, j|
    print_node(str1.length, j)
  end
  print_node(str1.length, str2.length)
  puts "\n"
  
  # Edges
  str1.each_char.with_index do |char1, i|
    str2.each_char.with_index do |char2, j|
      puts "  /* \"#{char1}\", \"#{char2}\" */"
      print_edge("#{i}_#{j}", "#{i+1}_#{j}", "delete \"#{char1}\"")
      print_edge("#{i}_#{j}", "#{i}_#{j+1}", "insert \"#{char2}\"")
      print_edge("#{i}_#{j}", "#{i+1}_#{j+1}", "match") if char1 == char2
    end
    puts "  /* \"#{str1[i]}\", $end */"
    print_edge("#{i}_#{str2.length}", "#{i+1}_#{str2.length}", "delete \"#{str1[i]}\"")
    puts "\n"
  end
  str2.each_char.with_index do |char2, j|
    puts "  /* $end, \"#{str2[j]}\" */"
    print_edge("#{str1.length}_#{j}", "#{str1.length}_#{j+1}", "insert \"#{str2[j]}\"")
  end
end

str1 = ARGV[0] || "ABCABBA"
str2 = ARGV[1] || "CBABAC"

puts <<-EOS
digraph #{"\"#{ARGV[2]}\""||""} {
  layout="neato"
  edge [constraint=false, arrowhead=none, color="#DDDDDD"]
  node [shape=plaintext]

  "progress" [id="progress",pos="-0.15,0.15!",label="0/#{str1.length * str2.length}"]

EOS
puts "  \"algorithm\" [pos=\"#{(-0.15+(str1.length.to_f*@scale))/2.0},0.5!\",label=\"#{ARGV[2]}\"]" if ARGV[2]
print_char_pairs(str1, str2)
puts "}"
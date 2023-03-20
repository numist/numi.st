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
  puts "  \"#{from}\" -> \"#{to}\" [id=\"#{from}to#{to}\"] /* \"#{comment}\" */"
end

def print_char_pairs(str1, str2, style)
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
  puts "  node [shape=point, fixedsize=true, width=0, height=0, style=invis]\n\n"
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

puts <<-EOS
digraph {
  layout="neato"
  edge [constraint=false, arrowhead=open, color="#BBBBBB"]
  node [shape=plaintext]

  "progress" [shape=plaintext,pos="-0.15,0.15!",label="x/yy"]

EOS
print_char_pairs(ARGV[0] || "ABCABBA", ARGV[1] || "CBABAC", ARGV[2] || "dynamic")
puts "}"
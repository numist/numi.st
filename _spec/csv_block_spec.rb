# _spec/csv_block_spec.rb
require 'rspec'
require 'jekyll'
require 'liquid'
require 'capybara'
require_relative '../_plugins/csv_block'

describe Jekyll::CSVBlock do
  def render_csv_block(content, tag_options = "")
    # Render the content within a {% csv %} block
    Liquid::Template.parse("{% csv #{tag_options} %}#{content}{% endcsv %}")
                     .render({})
  end

  it 'renders a table with headers' do
    csv_content = "Name, Age, Occupation\nAlice, 30, Engineer\nBob, 25, Designer"
    output = render_csv_block(csv_content, "header:true")

    expect(output).to include('<table>')
    expect(output).to include('<th>Name</th>')
    expect(output).to include('<td>Alice</td>')
  end

  it 'renders a table without headers' do
    csv_content = "Alice, 30, Engineer\nBob, 25, Designer"
    output = render_csv_block(csv_content, "header:false")

    expect(output).not_to include('<th>')
    expect(output).to include('<td>Alice</td>')
  end

  it 'renders tables with headers by default' do
    csv_content = "Alice, 30, Engineer\nBob, 25, Designer"
    output = render_csv_block(csv_content)

    csv_content = "Name, Age, Occupation\nAlice, 30, Engineer\nBob, 25, Designer"
    output = render_csv_block(csv_content)

    expect(output).to include('<table>')
    expect(output).to include('<th>Name</th>')
    expect(output).to include('<td>Alice</td>')
  end

  it 'renders a single-row table with headers' do
    csv_content = "Name, Age, Occupation"
    output = render_csv_block(csv_content)

    expect(output).to include('<table>')
    expect(output).to include('<th>Name</th>')
  end

  it 'supports tab-separated values' do
    csv_content = "Name\tAge\tOccupation\nAlice\t30\tEngineer\nBob\t25\tDesigner"
    output = render_csv_block(csv_content, "separator:tab")

    expect(output).to include('<th>Name</th>')
    expect(output).to include('<td>30</td>')
  end

  it 'handles empty cells' do
    csv_content = "Name, Age, Occupation\nAlice, , Engineer\nBob, 25, "
    output = render_csv_block(csv_content)

    expect(output).to include('<td></td>')
    expect(output).not_to include('undefined method')
  end

  it 'handles leading empty cells' do
    csv_content = ", Age, Occupation\nAlice, , Engineer\nBob, 25, "
    output_html = render_csv_block(csv_content)
    output = Capybara::Node::Simple.new(output_html)

    expect(output).to have_selector("thead tr", count: 1) # Only one row in thead
    expect(output).to have_selector("thead tr:first-child th", count: 3)
  end

  it 'handles cells containing only periods' do
    csv_content = ".\t.\tCyl 1\t.\tCyl 2\t.\n.\t.\tFore\tAft\tFore\tAft\n"    
    output_html = render_csv_block(csv_content, "separator:tab")
    output = Capybara::Node::Simple.new(output_html)

    expect(output).to have_selector("thead tr", count: 1) # Only one row in thead
    expect(output).to have_selector("thead tr:first-child th", count: 6) # Six cells in the row
    expect(output).to have_selector("thead tr:first-child th:nth-child(1)", text: ".")
    expect(output).to have_selector("thead tr:first-child th:nth-child(2)", text: ".")
    expect(output).to have_selector("thead tr:first-child th:nth-child(3)", text: "Cyl 1")
    expect(output).to have_selector("thead tr:first-child th:nth-child(4)", text: ".")
    expect(output).to have_selector("thead tr:first-child th:nth-child(5)", text: "Cyl 2")
    expect(output).to have_selector("thead tr:first-child th:nth-child(6)", text: ".")

    expect(output).to have_selector("tbody tr", count: 1) # Only one row in tbody
    expect(output).to have_selector("tbody tr:first-child td", count: 6) # Six cells in the row
    expect(output).to have_selector("tbody tr:first-child td:nth-child(1)", text: ".")
    expect(output).to have_selector("tbody tr:first-child td:nth-child(2)", text: ".")
    expect(output).to have_selector("tbody tr:first-child td:nth-child(3)", text: "Fore")
    expect(output).to have_selector("tbody tr:first-child td:nth-child(4)", text: "Aft")
    expect(output).to have_selector("tbody tr:first-child td:nth-child(5)", text: "Fore")
    expect(output).to have_selector("tbody tr:first-child td:nth-child(6)", text: "Aft")
  end

  it 'handles empty leading and trailing cells with leading newline' do
    csv_content = "\n\t\tCyl 1\t\tCyl 2\t\n\t\tFore\tAft\tFore\tAft\n"
    output_html = render_csv_block(csv_content, "separator:tab")
    output = Capybara::Node::Simple.new(output_html)

    expect(output_html).to include('<th>Cyl 2</th>')

    expect(output).to have_selector("thead tr", count: 1) # Only one row in thead
    expect(output).to have_selector("thead tr:first-child th", count: 6) # Six cells in the row
    expect(output).to have_selector("thead tr:first-child th:nth-child(1):empty")
    expect(output).to have_selector("thead tr:first-child th:nth-child(2):empty")
    expect(output).to have_selector("thead tr:first-child th:nth-child(3)", text: "Cyl 1")
    expect(output).to have_selector("thead tr:first-child th:nth-child(4):empty")
    expect(output).to have_selector("thead tr:first-child th:nth-child(5)", text: "Cyl 2")
    expect(output).to have_selector("thead tr:first-child th:nth-child(6):empty")

    expect(output).to have_selector("tbody tr", count: 1) # Only one row in tbody
    expect(output).to have_selector("tbody tr:first-child td", count: 6) # Six cells in the row
    expect(output).to have_selector("tbody tr:first-child td:nth-child(1):empty")
    expect(output).to have_selector("tbody tr:first-child td:nth-child(2):empty")
    expect(output).to have_selector("tbody tr:first-child td:nth-child(3)", text: "Fore")
    expect(output).to have_selector("tbody tr:first-child td:nth-child(4)", text: "Aft")
    expect(output).to have_selector("tbody tr:first-child td:nth-child(5)", text: "Fore")
    expect(output).to have_selector("tbody tr:first-child td:nth-child(6)", text: "Aft")
  end

  it 'evaluates formulas' do
    csv_content = "Item, Quantity, Price, Total\nWidget, 2, 5, = 3 + 6"
    output = render_csv_block(csv_content)

    expect(output).to include('<td>9</td>') # 2 * 5 in Total column
  end

  it 'doesn\'t use scientific notation unnecessarily' do
    csv_content = "0.006, =A1*24.5"
    output = render_csv_block(csv_content, "header:false")

    expect(output).to include('<td>0.147</td>')
  end

  it 'evaluates formulas in headers' do
    csv_content = "Item, Quantity, Price, =6*9\nWidget, 2, 5, 54"
    output = render_csv_block(csv_content)

    expect(output).to include('<th>54</th>') # 2 * 5 in Total column
  end

  it 'evaluates formulas with references' do
    csv_content = "Item, Quantity, Price, Total\nWidget, 2, 5, =B2+1"
    output = render_csv_block(csv_content)

    expect(output).to include('<td>3</td>')
  end

  it 'evaluates formulas with multiple references to the same cell' do
    csv_content = "Item, Quantity, Price, Total\nWidget, =2, 5, =B2+B2"
    output = render_csv_block(csv_content)

    expect(output).to include('<td>4</td>')
  end

  it 'evaluates formulas with references to columns > 26' do
    csv_content = "=AD1 + 1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29"
    output = render_csv_block(csv_content, "header:false")

    expect(output).to include('<td>30</td>')
  end

  it 'evaluates formulas recursively' do
    csv_content = "Item, Quantity, Price, Total\nWidget, = C2 + 1, 5, =B2+1"
    output = render_csv_block(csv_content)

    expect(output).to include('<td>7</td>')
  end

  it 'evaluates formulas with references across columns' do
    csv_content = "Item, Quantity, Price, Total\nWidget, 2, 5, =SUM(B2:C2)"
    output = render_csv_block(csv_content)

    expect(output).to include('<td>7</td>')
  end

  it 'evaluates formulas with references across rows' do
    csv_content = "100\n150\n=SUM(A1:A2)"
    output = render_csv_block(csv_content, "header:false")

    expect(output).to include('<td>250</td>')
  end

  it 'understands currency?' do
    csv_content = "$100\n$150\n=SUM(A1:A2)"
    output = render_csv_block(csv_content, "header:false")

    # Alas, for now.
    # expect(output).to include('<td>$250</td>')
    expect(output).to include('<td>Error: A3 uses invalid formula: SUM($100,$150)</td>')
  end

  it 'evaluates formulas with rectangular references' do
    csv_content = "1, 10, =SUM(A1:B1)\n100, 1000, =SUM(A2:B2)\n=SUM(A1:A2), =SUM(B1:B2), =SUM(A1:B2)"
    output = render_csv_block(csv_content, "header:false")

    expect(output).to include('<td>11</td>')
    expect(output).to include('<td>101</td>')
    expect(output).to include('<td>1010</td>')
    expect(output).to include('<td>1100</td>')
    expect(output).to include('<td>1111</td>')
  end

  it 'reports invalid row ranges' do
    csv_content = "A, B\n= A2:A1, 20"
    output = render_csv_block(csv_content)

    expect(output).to include("Error: A2 references invalid range A2:A1")
  end

  it 'reports invalid column ranges' do
    csv_content = "A, B\n= B1:A1, 20"
    output = render_csv_block(csv_content)

    expect(output).to include("Error: A2 references invalid range B1:A1")
  end

  it 'reports self-referential equations' do
    csv_content = "A, B\n= A2, 3"
    output = render_csv_block(csv_content)
    expect(output).to include("Error: circular reference: A2")
  end

  it 'reports self-referential equations without headers' do
    csv_content = "A, B\n= A2, 3"
    output = render_csv_block(csv_content, "header:false")
    expect(output).to include("Error: circular reference: A2")
  end

  it 'reports evaluations with circular dependencies' do
    csv_content = "A, B\n= B2, = A2"
    output = render_csv_block(csv_content)
    expect(output).to include("Error: circular reference: A2, B2")
  end

  it 'reports evaluations with circular dependencies without headers' do
    csv_content = "A, B\n= B2, = A2"
    output = render_csv_block(csv_content, "header:false")
    expect(output).to include("Error: circular reference: A2, B2")
  end

  it 'reports evaluations with invalid row references' do
    csv_content = "A, B\n= B3, 20"
    output = render_csv_block(csv_content)
    expect(output).to include("Error: A2 references invalid cell B3")
  end

  it 'reports evaluations with invalid column references' do
    csv_content = "A, B\n= C1, 20"
    output = render_csv_block(csv_content)
    expect(output).to include("Error: A2 references invalid cell C1")
  end

  it 'reports evaluations with invalid range references' do
    csv_content = "A, B\n= A1:C3, 20"
    output = render_csv_block(csv_content)
    expect(output).to include("Error: A2 references invalid range A1:C3")
  end

  it 'reports evaluations with formula syntax errors' do
    csv_content = "A, B\n= 5 + *, 20"
    output = render_csv_block(csv_content)
    expect(output).to include("Error: A2 uses invalid formula: 5 + *")
  end

  it 'reports circular references to columns > 26' do
    csv_content = "0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, =AD1"
    output = render_csv_block(csv_content, "header:false")

    expect(output).to include("Error: circular reference: AD1")
  end
end

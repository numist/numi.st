# _spec/csv_block_spec.rb
require 'rspec'
require 'jekyll'
require 'liquid'
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

  it 'evaluates formulas' do
    csv_content = "Item, Quantity, Price, Total\nWidget, 2, 5, = 3 + 6"
    output = render_csv_block(csv_content)

    expect(output).to include('<td>9</td>') # 2 * 5 in Total column
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

  it 'evaluates formulas with rectangular references' do
    csv_content = "1, 10, =SUM(A1:B1)\n100, 1000, =SUM(A2:B2)\n=SUM(A1:A2), =SUM(B1:B2), =SUM(A1:B2)"
    output = render_csv_block(csv_content, "header:false")

    expect(output).to include('<td>11</td>')
    expect(output).to include('<td>101</td>')
    expect(output).to include('<td>1010</td>')
    expect(output).to include('<td>1100</td>')
    expect(output).to include('<td>1111</td>')
  end

# TODO: test backwards ranges

  it 'detects and reports self-referential equations' do
    csv_content = "A, B\n= A2, 3"
    output = render_csv_block(csv_content)
    expect(output).to include("Error: circular reference: A2")
  end

  it 'detects and reports self-referential equations without headers' do
    csv_content = "A, B\n= A2, 3"
    output = render_csv_block(csv_content, "header:false")
    expect(output).to include("Error: circular reference: A2")
  end

  it 'detects and reports evaluations with circular dependencies' do
    csv_content = "A, B\n= B2, = A2"
    output = render_csv_block(csv_content)
    expect(output).to include("Error: circular reference: A2, B2")
  end

  it 'detects and reports evaluations with circular dependencies without headers' do
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
end

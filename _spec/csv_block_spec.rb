# spec/csv_block_spec.rb
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

  it 'supports tab-separated values' do
    csv_content = "Name\tAge\tOccupation\nAlice\t30\tEngineer\nBob\t25\tDesigner"
    output = render_csv_block(csv_content, "separator:tab")

    expect(output).to include('<th>Name</th>')
    expect(output).to include('<td>30</td>')
  end

  it 'evaluates basic formulas in cells' do
    csv_content = "Item, Quantity, Price, Total\nWidget, 2, 5, =SUM(B2...C2)"
    output = render_csv_block(csv_content, "header:true")

    expect(output).to include('<td>10</td>') # 2 * 5 in Total column
  end

  it 'evaluates formulas with references across rows and columns' do
    csv_content = "Product, Q1, Q2, Total\nGadget, 100, 150, =SUM(B2...C2)"
    output = render_csv_block(csv_content, "header:true")

    expect(output).to include('<td>250</td>') # 100 + 150 in Total column
  end

  it 'detects and reports circular dependencies' do
    csv_content = "= B1, = A1"
    output = render_csv_block(csv_content, "header:false")
    expect(output).to include("Error: Circular Reference at cell [0, 1]")
  end

  it 'detects and reports circular dependencies with headers' do
    csv_content = "A, B\n= B2, = A2"
    output = render_csv_block(csv_content, "header:true")
    expect(output).to include("Error: Circular Reference at cell [0, 1]")
  end

  it 'reports out-of-bounds references' do
    csv_content = "A, B\n= B3, 20"
    output = render_csv_block(csv_content, "header:true")
    expect(output).to include("Error: Out of Bounds reference B3 at row 2, col 1")
  end

  it 'reports invalid column references' do
    csv_content = "A, B\n= C1, 20"
    output = render_csv_block(csv_content, "header:true")
    expect(output).to include("Error: Invalid Column Reference C")
  end

  it 'reports formula syntax errors' do
    csv_content = "A, B\n= 5 + *, 20"
    output = render_csv_block(csv_content, "header:true")
    expect(output).to include("Error: Formula Evaluation in cell [0, 0]")
  end
end

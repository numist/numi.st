---
layout: page
excerpt: diff diff diff
---

<script>
  // Extend Array with a function that returns a new array with only unique elements
  Array.prototype.uniq = function() {
    return [...new Set(this)]
  }

  // object type to hold the animation state
  function AnimationState(svg_id, exploration_steps, solution_steps) {
    this.svg = document.getElementById(`${svg_id}`);
    this.exploration_steps = exploration_steps;
    this.solution_steps = solution_steps;
    this.total_steps = exploration_steps.length + solution_steps.length;
    this.index = 0;
    this.intervalId = null;

    this.changeColor = function() {
      if (this.index >= this.total_steps) {
        // change the stroke color of all the svg's paths back to "#ddd"
        this.svg.querySelectorAll("path").forEach(function(e) {
          e.setAttribute("stroke", "#ddd");
          e.setAttribute("stroke-width", "1");
        });
        this.index = 0;
        this.svg.querySelector(`g.node#progress text`).textContent = `0/${this.exploration_steps.length}`;
        return
      } else if (this.index < this.exploration_steps.length) {
        // change the color of the next exploration edge to #000, or #888 if it was already #000
        let edge = this.svg.querySelector(`g.edge#edge_${this.exploration_steps[this.index]} path`);
        if (edge.getAttribute("stroke") === "#000") {
          edge.setAttribute("stroke", "#888");
        } else {
          edge.setAttribute("stroke", "#000");
        }
        edge.setAttribute("stroke-width", "2");

        // update the progress counter
        // the numerator is the number of unique edges that have been explored
        let numerator = this.exploration_steps.slice(0, this.index + 1).uniq().length;
        // the denominator is the number of unique edges
        let denominator = this.exploration_steps.uniq().length;
        // update the counter
        this.svg.querySelector(`g.node#progress text`).textContent = `${numerator}/${denominator}`;
      } else {
        // Change the color of the next solution edge to green
        let edge = this.svg.querySelector(`g.edge#edge_${this.solution_steps[this.index - this.exploration_steps.length]} path`);
        edge.setAttribute("stroke", "#0b0");
      }

      this.index++;
      if (this.index >= this.total_steps) {
        clearInterval(this.intervalId);
        this.intervalId = null;
      }
    }

    this.svg.querySelector(`g.node#progress text`).textContent = `0/${this.exploration_steps.uniq().length}`;
  }
</script>


## TODO:

* [x] How heinous will it be to get the edges in the SVG to have useful ids?
    * [It's easy!](https://graphviz.org/docs/outputs/#ID)
* [x] Write a `shell` Liquid tag for Jekyll that exec's in the file's directory
    * Use it to produce diffing graphs: {% raw %}`{% shell generate_graph.rb ABCAB CBABA %}`{% endraw %}
* [x] Write animation code driven by the above collections of edge ids
    * resist the temptation to let readers customize their diffs by switching to a JS graphviz and bespoke diffing toolchain
* [x] Write diffing animations scripts for:
    * [x] Breadth-first ABCAB v CBABA
    * [x] Greedy Best First Search ABCAB v CBABA
    * [x] Myers ABCAB v CBABA
    * [x] Myers meet-in-the-middle ABCAB v CBABA

Post plan
* Diffing
    * Intro (introduce LCS)
    * Breadth-First
    * Greedy Breadth-First Search
    * Myers
    * Myers meet-in-the-middle
    * Worst Case
    * Historical Optimizations: What if you don't _need_ LCS? (Trading off Either Correctness or Degenerate Edge Performance)
        * heckel
        * Divide and Conquer: patience
    * New Frontiers
        * Membership testing
        * n-grams

* Future:
    * Membership testing
        * Membership PARTS v MIRTH
        * Membership-after PARTS v STRAP
    * Inexact diffing
        * limited-breadth Myers
        * arrow

## Animation Prototype

(click the grapth below to start/stop)

{% graphviz graph_bfs %}{% shell ./generate_graph.rb ABCAB CBABA "Breadth-First Search" %}{% endgraphviz %}
<script>
  const bfs_steps = ["0_0to1_0", "0_0to0_1", "1_0to2_0", "1_0to1_1", "0_1to0_2", "2_0to3_0", "2_0to3_1", "2_0to2_1", "1_1to2_2", "1_1to1_2", "0_2to1_3", "0_2to0_3", "3_0to4_0", "3_1to4_1", "3_1to3_2", "2_2to2_3", "1_3to2_4", "1_3to1_4", "0_3to0_4", "4_0to5_0", "4_1to5_1", "4_1to5_2", "4_1to4_2", "3_2to4_3", "3_2to3_3", "2_4to3_4", "2_4to2_5", "1_4to1_5", "0_4to0_5", "5_2to5_3", "4_3to5_4", "4_3to4_4", "3_4to4_5", "3_4to3_5", "5_4to5_5"];
  const bfs_solution_steps = ["5_4to5_5", "4_3to5_4", "3_2to4_3", "3_1to3_2", "2_0to3_1", "1_0to2_0", "0_0to1_0"];
  let bfs_animation_state = new AnimationState("graph_bfs", bfs_steps, bfs_solution_steps);
  bfs_animation_state.svg.addEventListener("click", function() {
    if (bfs_animation_state.intervalId === null) {
      bfs_animation_state.intervalId = setInterval(bfs_animation_state.changeColor.bind(bfs_animation_state), 500);
    } else {
      clearInterval(bfs_animation_state.intervalId);
      bfs_animation_state.intervalId = null;
    }
  });
</script>

## Graphs

{% capture gitsha %}{% shell git rev-parse HEAD %}{% endcapture %}
DOT generated by [`generate_graph.rb`](https://github.com/numist/numi.st/tree/{{ gitsha | strip }}/_posts/2023-03-18-diffing/generate_graph.rb), rendered by [a Jekyll graphviz plugin]({% post_url 2023-03-17-graphviz %})

### Breadth-First Search

The naive way to solve this problem is by traversing the graph breadth-first until the corners are connected by a line.

{% graphviz %}{% shell ./generate_graph.rb ABCAB CBABA "Breadth-First Search" %}{% endgraphviz %}

``` javascript
// Edge animation steps for breadth-first search
const bfs_steps = ["0_0to1_0", "0_0to0_1", "1_0to2_0", "1_0to1_1", "0_1to0_2", "2_0to3_0", "2_0to3_1", "2_0to2_1", "1_1to2_2", "1_1to1_2", "0_2to1_3", "0_2to0_3", "3_0to4_0", "3_1to4_1", "3_1to3_2", "2_2to2_3", "1_3to2_4", "1_3to1_4", "0_3to0_4", "4_0to5_0", "4_1to5_1", "4_1to5_2", "4_1to4_2", "3_2to4_3", "3_2to3_3", "2_4to3_4", "2_4to2_5", "1_4to1_5", "0_4to0_5", "5_2to5_3", "4_3to5_4", "4_3to4_4", "3_4to4_5", "3_4to3_5", "5_4to5_5"]
```

### Greedy Breadth-First

If you're familiar with graph theory, you'll recognize this as a shortest path problem. Sure enough, the next most efficient way to solve it is by giving each horizontal and vertical edge some cost (diagonals are free) and running Dijkstra's algorithm (or in this case, a greedy breadth-first search, since it's easier to animate)

{% graphviz %}{% shell ./generate_graph.rb ABCAB CBABA "Greedy Breadth-First" %}{% endgraphviz %}

``` javascript
// Edge animation steps for greedy breadth-first search
const bfs_steps = ["0_0to1_0", "0_0to0_1", "1_0to2_0", "1_0to1_1", "0_1to0_2", "2_0to3_0", "2_0to3_1", "3_1to4_1", "3_1to3_2", "2_0to2_1", "1_1to2_2", "2_2to2_3", "1_1to1_2", "0_2to1_3", "1_3to2_4", "2_4to3_4", "2_4to2_5", "1_3to1_4", "0_2to0_3", "3_0to4_0", "4_1to5_1", "4_1to5_2", "5_2to5_3", "4_1to4_2", "3_2to4_3", "4_3to5_4", "5_4to5_5"]
```

### Myers

But shortest-path graph traversals never caught on as solutions for diffing because the person who first recognized it as a graph problem[^obvious] _also_ realized that "2 deletes and 2 inserts" may represent up to four different paths<!--TODO-- a>nd an optimal algorithm only needs to keep track of the one that's made the most progress.

[^obvious]: When I asked him about it, Gene told me graph representation "seemed rather obvious" but I'd still argue that seeming inevitable in retrospect is a hallmark of good design

{% graphviz %}{% shell ./generate_graph.rb ABCAB CBABA Myers %}{% endgraphviz %}

``` javascript
// Edge animation steps for Myers
const myers_steps = ["0_0to1_0", "0_0to0_1", "1_0to2_0", "1_0to1_1", "0_1to0_2", "2_0to3_1", "3_1to4_1", "3_1to3_2", "1_1to2_2", "2_2to2_3" /* undone by 2_4to3_4 */, "0_2to1_3", "1_3to2_4", "2_4to3_4", "2_4to2_5", "4_1to5_2", "5_2to5_3", "3_2to4_3", "4_3to5_4", "5_4to5_5"]
```

#### Myers' "Middle Snake"

{% graphviz %}{% shell ./generate_graph.rb ABCAB CBABA "Myers Meet-in-the-Middle" %}{% endgraphviz %}

### Membership Testing

{% graphviz %}{% shell ./generate_graph.rb PARTS MIRTH "Membership Testing Example" %}{% endgraphviz %}

### Worst Case (back to O(n²))

{% graphviz %}{% shell ./generate_graph.rb PARTS STRAP "Worst Case" %}{% endgraphviz %}

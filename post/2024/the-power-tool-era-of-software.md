---
layout: page
title: "On Power Tools"
description: "Using the history of woodworking as a metaphor for the present (and future?) of software development."
published_at: Thu Sep 19 23:53:34 PDT 2024
---

I like to do a bit of woodworking in my spare time, a craft with a history that probably goes back to when hominids first learned how to knap rocks into adzes. As a profession, woodworking was incredibly labour-intensive until the Industrial Revolution, but hobbies tend to be fairly effort-insensitive and the quality of handmade hardwood furniture inspires such romance that many practitioners would go out of their way to identify specifically as "traditional woodworkers", a euphemism for their exclusive[^tradition] use of hand tools.

In the 1600s, a chair would have been made with handsaws, planes, chisels, brace and bit, drawknife, and spokeshave. Today the same chair could be built in a fraction of the time using a lathe, power drill, orbital sander, and the "big four"[^bigfour]—all "power" tools. Harnessing a power source to operate woodworking tools was so revolutionary that it upended the economics of the industry; suddenly the wood itself dominated the cost of producing furniture, leading to further innovations to reduce material costs, like particle board.

I write software in my work time, a craft with a history that arguably goes back to punch card looms but is more practically dated to the development of assembly language in 1947. Compared to woodworking, software is in its infancy. And if you work in software today, you use a text editor to write source code by hand, using terms that map _fairly_ straightforwardly[^straightforward] to machine code. You are a "traditional developer" in a craft that is witnessing the arrival of its first power tools.

Yes, this is a post about AI. Please bear with me[^bear].

## Some History

I worked in an AI research lab at my university during the early 2000s[^bayes]. Since that time, GPU performance has increased by 10,000⨉[^gpu] and clustering improvements have multiplied _that_ by an additional 1,000⨉. Early large-model projects like DeepDream (2015) were obvious indicators that the field had long been compute-bound and that modern hardware was finally sufficient for training models capable of producing emergent behaviour.

More recent models have generated an enormous amount of hype (and a bubble), but the pace of improvement these days is truly unprecedented. The past nine years have been more productive for AI research than the previous thirty. The technology is useful, even if many of the ways we're currently using it are not. Skeptics may (accurately!) point out that prompt-based AI tools trivially facilitate fraud and disinformation, but I would argue that chat-style generative interfaces are the least interesting application of this technology.

## Power Tools

If a power tool for woodworking is something that shapes wood without a human drawing a blade, a power tool for software is something that produces functioning code without a human typing any of its source. Software development entered its "power tool era" with the arrival of GPT 3.5 (or equivalent) models, and the tools keep improving. Newer models have proven to be significantly more capable, adding a compilation feedback loop has allowed them to produce higher quality results with less intervention, and local source access has allowed them to answer high-level questions about those sources and generate code that adopts its conventions and local interfaces.

Simon Willison has [been](https://simonwillison.net/2024/Mar/22/claude-and-chatgpt-case-study/) [demonstrating](https://simonwillison.net/2024/Mar/23/building-c-extensions-for-sqlite-with-chatgpt-code-interpreter/) the [usefulness](https://simonwillison.net/2024/Mar/26/llm-cmd/) of [these tools](https://simonwillison.net/2024/Jun/21/search-based-rag/) [over](https://simonwillison.net/2024/Aug/8/django-http-debug/) and [over](https://simonwillison.net/2024/Aug/26/gemini-bounding-box-visualization/), but realizing it for myself (while adding features to this blog) was a big moment for me. I knew nothing about Jekyll, and I still barely know Ruby, JavaScript, or modern (S)CSS practices, but I have been writing software since 1990 and it has felt _incredible_ to use these tools to quickly hack something useful together and then spend the rest of the evening editing it to production quality. And I don't consider that last step to be optional—as with woodworking, I expect the highest quality software products will always require some manual labour to produce.

## Hybrid Woodworking

It's at this point that woodworkers may offer a cautionary tale to their friends in software.

The furniture industry has become ever more efficient. A CNC is yet another quantum leap in productivity—a machine that knows how to operate power tools on its own with emotionless precision, limited only by its number of axes. Engineered wood is the norm[^engineered], and hollow core construction especially makes furniture feel flimsy and cheap. Which it is! But the quality hasn't declined nearly as much as the price, and the furniture is _good enough_. The remaining market for solid wood furniture is _tiny_ and many of _those_ products (like our dining room table) are so optimized for manufacturing that they employ joinery that will be lucky to survive a decade of use, let alone a lifetime.

Power tools took most of the blame that capitalists deserved, and over time "traditional woodworking" became a hobbyist dogma. It was only around 2013[^marc] when people came back around and stopped seeing power tools as _necessarily_ producing works of inferior quality.

A similar arc is already happening with AI, but it doesn't have to. Just as woodworkers know a miter saw can't cut a mortice, software developers ought to be familiar with their own tools' strengths and weaknesses. Today's power tools are not great at designing APIs, fairly useful for helping you implement them, and _super_ at writing tests. They are good at answering basic questions when you're learning something new[^ruby], more helpful than a rubber duck, but they tend to be gullible. They are _excellent_ translators, which effectively makes software development expertise portable between languages and ecosystems.

And once you've taken advantage of your power tools' strengths you can put them away, pull a block plane out of your apron, smooth out the rough edges, and wind up with something that's just as good as if you'd made it entirely by hand.

[^tradition]: Except for milling, which is _extraordinarily_ labour-intensive.
[^bigfour]: The four power tools required for milling: band saw, jointer, planer, and table saw.
[^straightforward]: Since I already footnoted an exception for milling I may as well compromise my metaphor by excusing compilers, for the same reason.
[^bayes]: We were focused on Bayesian neural networks, which [has been making a comeback](https://brandinho.github.io/bayesian-perspective-q-learning/) as a remedy for model overconfidence.
[^gpu]: When used for FP16-heavy workloads common to neural nets the GeForce 4 Ti was good for around 30 GFLOPS while an A100 is capable of 312 TFLOPS, though keen readers might also note that the Pentium 4 was good for around 100 GFLOPS. We weren't really using GPUs for these workloads twenty years ago.
[^engineered]: In its defense, engineered wood has significant practical advantages over solid wood. It's stable, consistent, and can be stronger too. But it's also _ugly_ in a way that screams "I'm cheap".
[^marc]: As far as I know this can largely be attributed to Marc Spagnuolo and his book [Hybrid Woodworking](https://thewoodwhisperer.com/product/hybrid-woodworking-book/).
[^ruby]: I'm lucky enough to be friends with some extraordinarily talented Ruby developers and I would have been _mortified_ to ask them some of the things that I typed without a second thought into GPT-4, which always answered (usually correctly!) without any judgement.
[^bear]: Or check out [On Steam Power](/post/2024/on-steam-power/) first.
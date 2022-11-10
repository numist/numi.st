---
layout: post
excerpt: "Why auto-merge dependency updates without review?"
---

This blog uses a [GitHub Action](https://github.com/numist/numi.st/blob/main/.github/workflows/merge-dependabot.yml) to automatically merge pull requests from dependabot so long as the Netlify deploy preview check succeeds. It was a bit of a pain to get going, and always seemed like a process that could have been trivially automated by GitHub.

Of course, that was on purpose:

<!-- There's a blog post here about how frameworks are opinionated and friction should (and does!) get used to guide people towards more canonical code by design -->

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Sometimes folks ask me why <a href="https://twitter.com/dependabot?ref_src=twsrc%5Etfw">@dependabot</a> doesn&#39;t support automerge. It&#39;s convenient, and seems like it should just work. So why doesn&#39;t it? 1/n</p>&mdash; Justin Hutchings (@jhutchings0) <a href="https://twitter.com/jhutchings0/status/1587126115218620417?ref_src=twsrc%5Etfw">October 31, 2022</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

While I agree with Justin that researchers are more likely to audit packages than clients, Accelerate[^accel] makes a compelling case that it's still better to aggressively deploy both good and bad packages faster than stall either. Besides, security-sensitive projects already know who they are and have integration processes for auditing dependency updates promptly; automerge is for the rest of us.

[^accel]: Forsgren, Nicole, et al. [_Accelerate: The Science of Lean Software and DevOps: Building and Scaling High Performing Technology Organizations._](https://itrevolution.com/product/accelerate/) IT Revolution, 2018.
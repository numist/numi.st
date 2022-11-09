---
layout: default
date: Jan 10 20:40:12 2022
---

<div class="home">
  {%- if site.posts.size > 0 -%}
    <div class="row row-cols-2 row-cols-md-3 g-4" data-masonry='{"percentPosition": true }'>
      {%- for post in site.posts -%}
        <div class="col-sm-6 col-lg-4 mb-4">
          <div class="card">
            {%- if post.image -%}
            <img style="width: 100%; height: 156px; object-fit: cover;" src="{{ post.url | append: post.image }}" class="card-img-top" alt="...">
            {%- endif -%}
            <div class="card-body">
              <h5 class="card-title">
                <a class="post-link stretched-link" target="_self" href="{{ post.link | default: post.url | relative_url }}">
                  {{ post.title | markdownify | remove: '<p>' | remove: '</p>' }}
                </a>
              </h5>
              {%- if site.show_excerpts -%}
                <p class="card-text">
                  {{ post.description | default: post.excerpt | markdownify | remove: '<p>' | remove: '</p>' }}
                </p>
              {%- endif -%}
              <div class="post-meta">
                {{ post.date | date: "%b %-d, %Y" }}
              </div>
            </div>
          </div>
        </div>
      {%- endfor -%}
    </div>
  {%- endif -%}
</div>

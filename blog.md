---
layout: default
---

<div class="home container">
  {%- if site.published.size > 0 -%}
    <div class="row row-cols-2 row-cols-md-3 g-4" data-masonry='{"percentPosition": true }'>
      {%- for post in site.published -%}
        {%- include postcard.html -%}
      {%- endfor -%}
    </div>
  {%- endif -%}
</div>

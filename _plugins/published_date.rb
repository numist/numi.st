# This plugin injects the `published_at` field into the front matter of each
# post based on the date in the filename. In combination with the
# `CustomPublishedGenerator` plugin, this allows us to iterate over all
# published content in one place with:
#
#     {% for post in site.published %}…{% endfor %}

module PublishedDate
  def self.inject_publication_date(page)
    # The last component of page.path should start with YYYY-MM-dd-…; parse out the date.
    date_in_path = page.path.split('/')[-1].split('-')[0..2].join('-')
    return unless date_in_path =~ /^\d{4}-\d{2}-\d{2}$/
    page.data['published_at'] = DateTime.parse(date_in_path)
  end

  Jekyll::Hooks.register :documents, :post_init do |page|
    inject_publication_date(page)
  end
end
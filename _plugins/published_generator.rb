# This plugin creates a new collection at `site.published` that contains
# all posts and pages with a `published_at` field. This allows us to
# iterate over all published content in one place.
#
# Usage: `{% for post in site.published %}…{% endfor %}`

module Jekyll
  class CustomPublishedGenerator < Generator
    priority :low

    def generate(site)
      published = []

      # Add posts with a published_at field to the published collection
      site.posts.each do |post|
        published << post if post.data['published_at']
      end

      # Add pages with a published_at field to the published collection
      site.pages.each do |page|
        published << page if page.data['published_at']
      end

      # Assign the combined published collection to site.published
      site.config['published'] = published.sort_by { |item| item.data["published_at"] } .reverse
    end
  end
end
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
      site.posts.docs.each do |post|
        if post.data['published_at']
          post.data['published_at'] = DateTime.parse(post.data['published_at']) if post.data['published_at'].is_a?(String)
          published << post
        end
      end

      # Add pages with a published_at field to the published collection
      site.pages.each do |page|
        if page.data['published_at']
          page.data['published_at'] = DateTime.parse(page.data['published_at']) if page.data['published_at'].is_a?(String)
          published << page
        end
      end

      # Assign the combined published collection to site.published
      site.config['published'] = published.sort_by { |item| item.data["published_at"] } .reverse
    end
  end
end
module UndatedPosts
  # class UndatedPostGenerator < Jekyll::Generator
  #   safe true
  #
  #   def generate(site)
  #     unmatched_post_paths.each do |path|
  #       site.posts << Jekyll::Document.new(path)
  #     end
  #   end
  # end

  # Add dates to everything
  class Date
    def self.inject_dates
      proc { |page|
        # detect when we've got undated document injection working
        raise "nil date for document" if page.data['date'].nil? and page.instance_of? Jekyll::Document
        page.data['date'] = "1969-12-31" if page.data['date'].nil?
        page.data['modified_at'] = Time.now()
      }
    end

    def initialize(payload)
      # called at time of page/document init
      @payload = payload
    end

    def to_liquid
      # called at time of use
      @payload
    end
  end

  Jekyll::Hooks.register :pages, :post_init, &Date.inject_dates
  Jekyll::Hooks.register :documents, :pre_render, &Date.inject_dates
end
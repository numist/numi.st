module UndatedPosts
  # Add dates to everything
  class Date
    class << self
      def git_init(site)
        @@git = Git.new(site)
      end
      
      def inject_dates
        proc { |page|
          # detect when we've got undated document injection working
          raise "nil date for document" if page.data['date'].nil? and page.instance_of? Jekyll::Document
          page.data['date'] = @@git.files[page.path]&[:last_created_at] || "1969-12-31" if page.data['date'].nil?
          page.data['modified_at'] = @@git.files[page.path]&[:last_modified_at] || Time.now()
        }
      end
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
  
  class Git
    attr_reader :files
    
    def initialize(site)
      Jekyll.logger.debug "jekyll-times: Initializing git cache"
      @site_path = site.source
      @files = {}
      # raise "#{@site_path}"
    end
  end

  # class UndatedPostGenerator < Jekyll::Generator
  #   safe true
  #
  #   def generate(site)
  #     unmatched_post_paths.each do |path|
  #       site.posts << Jekyll::Document.new(path)
  #     end
  #   end
  # end

  #
  # Hook registrations:
  #

  # Inject dates into all pages and documents
  Jekyll::Hooks.register :pages, :post_init, &Date.inject_dates
  Jekyll::Hooks.register :documents, :pre_render, &Date.inject_dates
  Jekyll::Hooks.register :site, :after_reset do |site|
    Date.git_init(site)
  end
end
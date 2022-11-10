require 'posix/spawn'

module UndatedPosts
  # Add dates to everything
  class Date
    class << self
      def git_init(site)
        @@git = Git.new(site)
      end
      
      def inject_dates(page)
        # detect when we've got undated document injection working
        raise "nil date for document" if page.data['date'].nil? and page.instance_of? Jekyll::Document
        page.data['date'] = @@git.files.dig(page.path, :last_created_at) || "1969-12-31" if page.data['date'].nil?
        page.data['modified_at'] = @@git.files.dig(page.path, :last_modified_at) || Time.now()
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
    
    def top_level_directory
      return nil unless git_repo?

      @top_level_directory ||= begin
        Dir.chdir(@site_source) do
          @top_level_directory = File.join(Executor.sh('git', 'rev-parse', '--show-toplevel'), '.git')
        end
      # is this rescue actually necessary? looks like it's handled in Executor…
      rescue StandardError
        nil
      end
    end
    
    def git_repo?
      @is_git_repo ||= begin
        Dir.chdir(@site_source) do
          Executor.sh('git', 'rev-parse', '--is-inside-work-tree').eql? 'true'
        end
      # is this rescue actually necessary? looks like it's handled in Executor…
      rescue StandardError
        false
      end
    end
    
    
    def initialize(site)
      Jekyll.logger.debug "         Resetting: git cache"
      @site_source = site.source
      @files = {}
      
      lines = Executor.sh(
        'git',
        '--git-dir',
        top_level_directory,
        'log',
        '--name-only',
        '--date=unix',
        '--pretty=%%these-files-modified-at:%ct'
      ).split("\n")

      timestamp = nil
      lines.each do |line|
        case
        when line.empty? # skip
        when line.start_with?('%these-files-modified-at:')
          timestamp = line.split(':')[1]
        else
          @files[line] = { last_modified_at: timestamp } unless @files.key?(line)
          @files[line][:last_created_at] = timestamp
        end
      end
    end
  end
  
  module Executor
    extend POSIX::Spawn

    def self.sh(*args)
      r, w = IO.pipe
      e, eo = IO.pipe
      pid = spawn(
        *args,
        :out => w, r => :close,
        :err => eo, e => :close
      )

      if pid.positive?
        w.close
        eo.close
        out = r.read
        err = e.read
        ::Process.waitpid(pid)
        "#{out} #{err}".strip if out
      end
    ensure
      [r, w, e, eo].each do |io|
        begin
          io.close
        rescue StandardError
          nil
        end
      end
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
  Jekyll::Hooks.register :pages, :post_init do |page|
    Date.inject_dates(page)
  end
  Jekyll::Hooks.register :documents, :pre_render do |page|
    Date.inject_dates(page)
  end
  Jekyll::Hooks.register :site, :after_reset do |site|
    Date.git_init(site)
  end
end
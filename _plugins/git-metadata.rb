require 'posix/spawn'

# XXX: Should this ever become a package, it'll need tests. Things like:
# * singly-committed test file has birthtime == mtime and sha
# * renamed test file has expected birthtime and mtime and sha
# * untracked test file has unix birthtime and mtime no sha
# * ENOENT file has Time.now for both no sha
# * test file that was previously deleted and recreated has last birthtime
# * test untracked file that was touched after creation has a birthtime that is later than its mtime?
# * all of the above, but with a file that has a space in its name

module GitMetadata
  def self.birthtime(path)
    raise "file #{path} does not exist" unless File.exist?(path)
    File.birthtime(path)
  end
  
  def self.mtime(path)
    return nil unless File.exist?(path)
    File.mtime(path)
  end
  
  def self.inject_dates(page)
    # detect when we've got undated document injection working
    raise "nil date for document" if page.data['date'].nil? and page.instance_of? Jekyll::Document
    # raise if the document is not markdown
    return unless page.path.end_with?('.md') or page.path.end_with?('.html')

    git_created_at, git_modified_at = Git.file_times(page.path) || [nil, nil]
    created_at = git_created_at || birthtime(page.path)
    modified_at = git_modified_at || mtime(page.path)

    page.data['created_at'] = created_at
    page.data['date'] = created_at if page.data['date'].nil?
    page.data['modified_at'] = modified_at
  end

  class Git
    class << self
      def branch
        @@branch ||= Executor.sh(
          "git",
          "rev-parse",
          "--abbrev-ref",
          "HEAD"
        ).strip
      end

      def init(site)
        Jekyll.logger.debug "         Resetting: git cache"
        @@site_source = site.source
        @@branch = nil
      end

      # this function returns the last created_at and last_modified_at times for
      # the path given. raises an error if the path is a directory or does not exist.
      # returns nil if the path is untracked.
      def file_times(path)
        raise "file #{path} does not exist" unless File.exist?(path)
        raise "file #{path} is a directory" if File.directory?(path)
        return nil unless git_repo?

        # Use `git log --follow --format=%ad --date iso <path>` to get
        # all the dates that `path` was modified.
        times = Executor.sh(
          "git",
          "log",
          "--follow",
          "--format=%ad",
          "--date", "iso",
          path
        ).split("\n")

        # If `path` was never modified, `git log` will return an empty string.
        return nil if times.empty?

        # `git log` returns the dates in reverse chronological order.
        # The first date is the last time the file was modified.
        # The last date is the first time the file was modified.
        # We want to return the first and last dates.
        begin
          [DateTime.parse(times.last), DateTime.parse(times.first)]
        rescue Date::Error
          Jekyll.logger.warn "Error: could not parse dates for #{path}: #{times}"
          nil
        end
      end

      def top_level_directory
        return nil unless git_repo?

        @@top_level_directory ||= begin
          Dir.chdir(@@site_source) do
            @@top_level_directory = File.join(Executor.sh('git', 'rev-parse', '--show-toplevel'), '.git')
          end
        # is this rescue actually necessary? looks like it's handled in Executor…
        rescue StandardError
          nil
        end
      end

      def git_repo?
        @@is_git_repo ||= begin
          Dir.chdir(@@site_source) do
            Executor.sh('git', 'rev-parse', '--is-inside-work-tree').eql? 'true'
          end
        # is this rescue actually necessary? looks like it's handled in Executor…
        rescue StandardError
          false
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

  Jekyll::Hooks.register :pages, :post_init do |page|
    inject_dates(page)
  end
  Jekyll::Hooks.register :documents, :pre_render do |page|
    inject_dates(page)
  end
  Jekyll::Hooks.register :site, :after_reset do |site|
    Git.init(site)
  end
  Jekyll::Hooks.register :site, :pre_render do |site, payload|
    payload['site']["git_head"] = Git.branch
  end
end
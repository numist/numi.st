require 'posix/spawn'

# XXX: Should this ever become a package, it'll need tests. Things like:
# * singly-committed test file has ctime == mtime and sha
# * renamed test file has expected ctime and mtime and sha
# * untracked test file has unix ctime and mtime no sha
# * ENOENT file has Time.now for both no sha
# * test file that was previously deleted and recreated has last ctime

module GitMetadata
  def self.ctime(path)
    return nil unless File.exist?(path)
    File.ctime(path)
  end
  
  def self.mtime(path)
    return nil unless File.exist?(path)
    File.mtime(path)
  end
  
  def self.inject_dates(page)
    # detect when we've got undated document injection working
    raise "nil date for document" if page.data['date'].nil? and page.instance_of? Jekyll::Document

    # Sometimes page.path is an absolute path, sometimes it's relative.
    # Need it to always be relative for hash lookup.
    relative_path = if page.path.start_with?('/')
      Pathname.new(page.path)
        .relative_path_from(
          Pathname.new(File.dirname(Git.top_level_directory))
        ).to_s
    else
      page.path
    end

    page.data['date'] = Git.files.dig(relative_path, :last_created_at) || ctime(relative_path) || Time.now if page.data['date'].nil?
    page.data['modified_at'] = Git.files.dig(relative_path, :last_modified_at) || mtime(relative_path) || Time.now
    page.data['commit'] = Git.files.dig(relative_path, :commit)
  end

  class Git
    class << self

      def files
        @@files ||= populate_files
      end

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
        @@files = nil
      end

      def populate_files
        @@files = {}
        timestamp = nil
        commit = nil

        Executor.sh(
          'git',
          '--git-dir',
          top_level_directory,
          'log',
          '--no-merges',
          '--reverse',
          '--name-status',
          '--date=unix',
          '--pretty=%%these-files-modified-at:%ct%n%%commit:%H'
        ).split("\n").each do |line|
          # Each commit is printed from oldest to newest in the format:
          #
          # %these-files-modified-at:1667711586
          # %commit:d2c2079f8b3d5b8056b4736849ac3b2d580a2827
          #
          # M       404.html
          # D       README.md
          # A       _plugins/raise_eror.rb
          # R92     foo bar.test    bar foo.test
          #
          # XXX: Note that none of this works properly if any of the filenames contain spaces!
          # Top level files with space-prefixed names are right out!
          # Another reason why this isn't ready for general consumption as a package!
          #
          # Probably what I need to do is rewrite this using https://github.com/libgit2/rugged
          case
          when line.start_with?('%these-files-modified-at:')
            timestamp = line.split(':')[1]
          when line.start_with?('%commit:')
            commit =  line.split(':')[1]
          when line.start_with?('A')
            # Added
            @@files[line.split[1]] = { last_created_at: timestamp, last_modified_at: timestamp, commit: commit }
          when line.start_with?('D')
            # Deleted
            @@files.delete(line.split[1])
          when line.start_with?('M')
            # Modified
            @@files[line.split[1]].merge!({ last_modified_at: timestamp, commit: commit })
          when line.start_with?('R')
            # Renamed
            @@files[line.split[2]] = @@files.delete(line.split[1]).merge!({ last_modified_at: timestamp, commit: commit })
          end
        end

        @@files
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
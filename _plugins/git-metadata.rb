require 'posix/spawn'

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
    page.data['date'] = Git.files.dig(page.path, :last_created_at) || ctime(page.path) || Time.now if page.data['date'].nil?
    page.data['modified_at'] = Git.files.dig(page.path, :last_modified_at) || mtime(page.path) || Time.now
    page.data['commit'] = Git.files.dig(page.path, :commit)
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
          '--name-only',
          '--date=unix',
          '--pretty=%%these-files-modified-at:%ct%n%%commit:%H'
        ).split("\n").each do |line|
          case
          when line.empty? # skip
          when line.start_with?('%these-files-modified-at:')
            timestamp = line.split(':')[1]
          when line.start_with?('%commit:')
            commit =  line.split(':')[1]
          else
            @@files[line] = { last_modified_at: timestamp, commit: commit } unless @@files.key?(line)
            @@files[line][:last_created_at] = timestamp
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
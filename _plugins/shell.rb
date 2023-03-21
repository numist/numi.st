# This plugin was written *entirely* by ChatGPT (Mar 14, 2023 Version) from the prompt:
#
#     Implement a Jekyll plugin that provides a liquid tag named "shell" that evaluates its parameters as a shell command in the same directory as the page, returning the output (and raising an error on a non-zero exit code).
#
# The robots are here and they make incredible interns.

require 'open3'
require 'pathname'

module Jekyll
  class ShellTag < Liquid::Tag
    def initialize(tag_name, command, tokens)
      super
      @command = command.strip
    end

    def render(context)
      page_path = context.registers[:page]["path"]
      page_dir = Pathname.new(page_path).dirname
      output, error, status = Dir.chdir(page_dir) { Open3.capture3(@command) }
      if status.success?
        output.strip
      else
        raise "Command `#{@command}` failed with exit code #{status.exitstatus}: #{error.strip}"
      end
    end
  end
end

Liquid::Template.register_tag('shell', Jekyll::ShellTag)

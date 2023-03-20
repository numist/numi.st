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
        raise "Command failed with exit code #{status.exitstatus}: #{error.strip}"
      end
    end
  end
end

Liquid::Template.register_tag('shell', Jekyll::ShellTag)

# ABOUTME: Serves the site's 404 page with the LiveReload script when `jekyll serve --livereload` gets a
# ABOUTME: request for a missing path, as it does for every other page.

module Jekyll
  # Sits between Jekyll's servlet and WEBrick's file handler, so that a missing file becomes the site's 404 page
  # before the servlet adds the LiveReload script, instead of an error that skips the servlet.
  module LiveReloadNotFoundPage
    def do_GET(req, res)
      super
    rescue WEBrick::HTTPStatus::NotFound => e
      @logger.error(e.message)
      res.set_error(e)
    end
  end
end

# Jekyll loads its servlet only to serve the site, and the patch matters only under `serve --livereload`,
# so the servlet is loaded and patched only then.
Jekyll::Hooks.register :site, :after_init do |site|
  next unless site.config['serving'] && site.config['livereload']

  require 'jekyll/commands/serve/servlet'
  Jekyll::Commands::Serve::Servlet.include(Jekyll::LiveReloadNotFoundPage)
end

source "https://rubygems.org"

gem "jekyll", "~> 4.3.4"
gem "posix-spawn", "~> 0.3.9"

group :jekyll_plugins do
  gem "jekyll-mermaid", "~> 1.0.0"
  gem "jekyll-postfiles", "~> 3.1"
  gem "jekyll-seo-tag", :git => 'https://github.com/numist/jekyll-seo-tag.git', :branch => 'issue/461'

  # Local plugin dependencies
  gem "ruby-graphviz"
  gem "dentaku"
end

group :development do
  gem "puma", "~> 6.4"
  gem "rack-jekyll", github: "adaoraul/rack-jekyll"
  gem "rack-livereload", "~> 0.6.1"
  gem "webrick", "~> 1.9"
end

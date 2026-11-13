# numi.st

Run Ruby commands under the version in `.ruby-version`, e.g. `chruby "$(cat .ruby-version)"`.

## Before committing

- [ ] `bundle exec rspec _spec` passes with clean output.
- [ ] `bundle exec jekyll build --destination "$(mktemp -d)"` succeeds. Build into a temporary directory so you don't clobber the `_site` used by Scott's `jekyll serve`.
- [ ] Every new or changed title in `_link_previews/links.yml` is plausibly the title of the page its URL points to. Flag any that aren't with an `error:`.
- [ ] The build prints no `Link preview: <page> links to <url>, which the page generates; …` warnings. External links built with Liquid need an inline title: `[text](url "Title")` in Markdown, or a `title` attribute in the layout or include; they can also name a favicon from `_link_previews/favicons/` with `data-preview-favicon`.
- [ ] The build prints no `Link preview: <page> links to <url>, which has no title; …` warnings. Give the linked page a title.

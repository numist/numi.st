# numi.st

## Before committing

- [ ] `bundle exec rspec _spec` passes with clean output.
- [ ] `bundle exec jekyll build` succeeds.
- [ ] Every new or changed title in `_link_previews/links.yml` is plausibly the title of the page its URL points to. Flag any that aren't with an `error:`.
- [ ] The build prints no "generated link" warnings. Links built with Liquid need an inline title: `[text](url "Title")` in Markdown, or a `title` attribute in the layout or include.

# Changelog

Unreleased
----------

* Formatted keys are memoized per builder instance. The default,
  formatterless path allocated a fresh String for every key emission — the
  library's largest allocation source (~20% of total allocations rendering a
  large collection).
* Fewer Ruby frames per emitted value on the hot path (`set!` and `extract!`
  inline the one-line `key!`/`value!` hops; encoder container checks
  simplified). With the memoized keys: roughly +14–20% throughput on the
  benchmark suites under the interpreter, +8–13% under YJIT.
* `json.null!` and `json.nil!` are implemented. Both were documented in the
  README but never defined, so they fell through `method_missing` to `set!` and
  emitted a `"null!"` key whose value was an inspected `Object`.
* Documented that `ActionController::API` silently skips layouts unless
  `ActionView::Layouts` is included.
* **Breaking:** `partial!` is now `partial!(name, locals: nil, **render_options)`.
  The partial name is the first argument, template locals go in `locals:`, and
  every other keyword is passed to Action View as a render option:
  `json.partial! 'post', locals: { post: @post }`. Previously bare keywords were
  locals and the name could be given as a `partial:` option.

  Nothing is reserved, so options TurboStreamer does not know about -- `cached:`,
  `layout:`, whatever Action View adds next -- reach it anyway, and a local may
  be named `formats` or `object` without being mistaken for an option. Both
  wrong shapes name the call that was meant.
  `json.array! @posts, partial: 'post', as: :post` is unaffected.
* `partial!` no longer writes to anything the caller passed it. `:as` was
  deleted out of the caller's locals and the builder stored in them, so
  rendering twice with one hash lost `:as` on the second call and rendered a
  collection differently. The options hash itself was written to as well,
  gaining `:handlers` and a `:locals` holding the builder.
* Fixed injected JSON -- and so `cache!`, which splices cached bytes -- losing
  or misplacing the separator next to a normally-rendered sibling. A cached
  fragment beside a rendered object in an array emitted `[{...}{...}]`, which is
  not valid JSON; on the Wankel encoder `[1,2]` could come back as `[12]`, which
  is valid but wrong. Both encoders now track what they wrote separately from
  what is present, so injected bytes are delimited correctly in either position.

2.0.0
-----

Breaking:

* Requires Rails 8.0+ and Ruby 3.3+.
* `write` is no longer aliased onto `ActionView::OutputBuffer` and
  `ActionView::StreamingBuffer`. Installing the gem used to add a non-escaping
  append to every buffer in the application; the encoders now write into
  `ActionView::TurboBuffer` instead. Code outside TurboStreamer that called
  `output_buffer.write` was relying on that alias and will need `safe_concat`.
* `ActionView::JSONStreamingBuffer` is now `ActionView::StreamingTurboBuffer`.

* Optimize internal `extract!` calls to save on memory allocation [PR #25](https://github.com/malomalo/turbostreamer/pull/25)
* Add `frozen_string_literal` magic comments
* Remove some old Rails code
* Add Rails 8.0 & 8.1 to CI; drop support for Rails < 8.0 and Ruby < 3.3
* Package `LICENSE` and `CHANGELOG.md` with the gem, and fix `spec.files` dropping
  everything but `README.md` when the gem is built on a shell without brace expansion
* Layouts now work. A `.json.streamer` layout places the template with
  `json.yield!`. Layout and template share one builder, so the template writes
  into the same stream rather than being buffered and spliced. The layout
  renders first and yields to the template, the reverse of an ERB layout.
  Applies both to `render stream: true` and to ordinary rendering; previously a
  streamed layout was resolved and then discarded, and an unstreamed one had no
  way to place the template's JSON at all.
* Fix streaming JSON raising `NoMethodError: undefined method 'instrument'`.
  `AbstractRenderer#instrument` was removed in Rails 6.1, so every streamed
  render failed -- silently, since `Body#each` rescues and substitutes an error
  page. It now notifies `render_template.action_view` directly.

1.11.0 - 2024-04-29
-----
* Fix timestamp precision for Rails [PR #24](https://github.com/malomalo/turbostreamer/pull/24)
* Fix CI yajl archive download URL [PR #22](https://github.com/malomalo/turbostreamer/pull/22)

1.10.0
-----
* Fixed Rails 6.1 & Ruby 3.0 Compatibility

1.9.0
-----
* Fixed deprecation of using `Proc.new` to capture block; replaced with `&block`

1.8.0
-----
* Make the StreamingRenderer Rails 6 compatible [PR #15](https://github.com/malomalo/turbostreamer/issues/15)
* Update gemspec to require Ruby 2.5+ [PR #14](https://github.com/malomalo/turbostreamer/issues/14)

1.7.0
-----
* Add the ability to set default options for encoders
* Allow setting the `buffer_size` on the OJ encode
* Reduce find_template calls [PR #11](https://github.com/malomalo/turbostreamer/pull/1)
* Don't require a layout to stream template in Rails

1.5.0
-----
* Add Rails 6.0 support
* Drop Rails 4.2 support

1.4.0
-----
* Replace deprecated fragment_cache_key for Rails 5.2 support

1.3.0
-----
* Bump version and update bundler

1.2.0
-----
* Add `TurboStreamer#merge!` to merge a hash or array into the current json stream.

1.1.0
-----
* Add `Oj` as an encoder option
* Add ability to pass encoder as an option to `TurboStreamer#new` (symbol or class)
* Ability to set default encoder for mime type with `TurboStreamer#set_default_encoder`
* Add some performance test

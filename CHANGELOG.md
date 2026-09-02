# Changelog

Unreleased
-----
* Optimize internal `extract!` calls to save on memory allocation [PR #25](https://github.com/malomalo/turbostreamer/pull/25)
* Add `frozen_string_literal` magic comments
* Remove some old Rails code
* Add Rails 7.2, 8.0 & 8.1 to CI; drop support for Rails < 7.2 and Ruby < 3.3
* Package `LICENSE` and `CHANGELOG.md` with the gem, and fix `spec.files` dropping
  everything but `README.md` when the gem is built on a shell without brace expansion
* Layouts now work when streaming. A `.json.streamer` layout calls `json.yield!`
  where the template's JSON belongs; the two share one builder, so the template
  writes into the same stream rather than being buffered and spliced. Previously
  the layout was resolved and then discarded.
* Fix streaming JSON raising `NoMethodError: undefined method 'instrument'`.
  `AbstractRenderer#instrument` was removed in Rails 6.1, so every streamed
  render failed -- silently, since `Body#each` rescues and substitutes an error
  page. It now notifies `render_template.action_view` directly.
* Stop aliasing `write` onto `ActionView::OutputBuffer` and
  `ActionView::StreamingBuffer`. The encoders now stream into `TurboStreamer::Buffer`,
  which wraps the ActionView buffer instead of patching it, so the non-escaping
  `write` is no longer added to every buffer in the application.
  `ActionView::JSONStreamingBuffer` moves to `TurboStreamer::StreamingBuffer`.

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

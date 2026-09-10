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
* Covered the failure mode when a partial exists for another handler but not
  for `:streamer`. Partial lookup is restricted to `:streamer`, which is what
  makes that raise `MissingTemplate` instead of rendering the other handler's
  template -- whose output `partial!` discards, since the builder writes to the
  stream itself, so the node would simply be absent from the response.

* Encoder options configured for an encoder now apply whether it is named by
  symbol or by class. `encoder: TurboStreamer::OjEncoder` found no options and
  silently dropped whatever was set for `:oj` -- including the railtie's
  `mode: :rails`, and so its HTML escaping -- where `encoder: :oj` kept them.

* `has_default_encoder_options?` no longer reports true for an encoder merely
  because something was rendered with it. Building a builder read through the
  options Hash's default proc, which assigns as it reads.

* **Breaking:** the calls this library refuses raise Ruby's `::ArgumentError`.
  The `TurboStreamer::Errors` module and `Errors::MergeError` are gone

* A key given no value, block or attributes on its own (e.g. `json.foo`) now
  raises `ArgumentError` naming the key.

* A value that is not a collection or array like with a block now raises
  `ArgumentError` naming its class.

* Attributes and a block given together now raise `ArgumentError` naming the
  attributes (e.g. `json.comments(@cs, :body) { |c| ... }`).

* Fixed the separator around injected JSON -- and so around `cache!`, which
  splices cached bytes -- in both encoders. A cached fragment beside a
  normally-rendered sibling in an array emitted `[{...}{...}]`, which is not
  valid JSON. On the Wankel encoder two cases were silent rather than loud:
  `[1,2]` came back as `[12]`, valid JSON carrying the wrong value. Both
  encoders now track whether an open container already holds something, and
  the Oj encoder hands array fragments to `Oj::StreamWriter#push_json` so the
  writer places the delimiter itself.
* Tests no longer leak TurboStreamer's class-level configuration into each
  other. `rake test:wankel` could silently run most of the suite on Oj: setting
  the default encoder to `:oj` loads Oj, and a teardown that blanked the
  defaults left `default_encoder_for` falling through to the first loaded
  encoder. Whether it happened depended on the random seed, so a green run did
  not mean the Wankel encoder had been exercised.

* The Wankel encoder refuses the same malformed shapes Oj's writer already
  refused, rather than writing broken JSON: a key inside an array (`["a",1]`
  from `merge!`-ing a Hash into an array), a key never given a value (`{"a"}`)
  and a value written without a key (`{"1"}`). All raise `::ArgumentError`
  saying what could not be written and where.

* `capture` copies rather than diverts. A block used to be rendered into a
  separate writer at the top level and the bytes spliced back in afterwards.
  Now the block renders where it stands and the bytes are copied as they go out,
  so a fragment is whatever the document received. `cache!` therefore only splices
  on a hit: a miss is already in the document.

* `cache!` now works under a key, caching that key's value:
  `json.author { json.cache!('k') { json.object! { ... } } }`. It used to raise
  on Oj and emit `{"author"{"a":1}}` on Wankel, because injected bytes go around
  the writer and the colon a key needs was never written. `inject` now
  recognises value position and lets the writer place the fragment.

  The cached bytes differ between the two forms, and usefully so. Over a key
  (`cache!` wrapping the key and its value) the fragment is a sequence of pairs
  and can cover several keys at once. Under a key it is a bare value, which
  carries no position -- so it replays anywhere a value belongs, and both
  encoders now write and read identical fragments.

* Added alba's benchmark suite under `performance/alba`, run with
  `rake performance:alba`. It is the suite whose figures get quoted at
  TurboStreamer, and the published ones predate 2.0.

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

# TurboStreamer

[![GitHub Build Status](https://img.shields.io/github/actions/workflow/status/malomalo/turbostreamer/ci.yml?branch=master&style=flat-square)](https://github.com/malomalo/turbostreamer/actions?query=workflow%3ACI)

[![Gem Version](https://img.shields.io/gem/v/turbostreamer.svg?style=flat-square)](https://rubygems.org/gems/turbostreamer)
[![License](https://img.shields.io/github/license/malomalo/turbostreamer.svg?style=flat-square)](https://github.com/malomalo/turbostreamer/blob/master/LICENSE)

TurboStreamer gives you a simple DSL like jBuilder for generating JSON that
streams directly to a String or IO object.

[Jbuilder](https://github.com/rails/jbuilder) builds a Hash as it renders the
template and once complete converts the Hash to JSON. TurboStreamer on the other
hand writes directly to the output as it is rendering the template. Because of
this some of the magic cannot be done and requires a little more verboseness.

Because no time is spent creating a hash caching is also fast. No time is spent
marshaling and unmarshaling from the cache, instead the string is cached and
directly inserted into the stream skipping any unmarshaling.

## Examples

``` ruby
# app/views/message/show.json.streamer

json.object! do
  json.content format_content(@message.content)
  json.extract! @message, :created_at, :updated_at

  json.author do
    json.object! do
      json.name @message.creator.name.familiar
      json.email_address @message.creator.email_address_with_name
      json.url url_for(@message.creator, format: :json)
    end
  end

  if current_user.admin?
    json.visitors calculate_visitors(@message)
  end

  json.tags do
    json.array! do
      @message.tags.each { |tag| json.child! tag }
    end
  end

  json.comments @message.comments, :content, :created_at

  json.attachments @message.attachments do |attachment|
    json.object! do
      json.filename attachment.filename
      json.url url_for(attachment)
    end
  end
end
```

This will build the following structure:

``` javascript
{
  "content": "<p>This is <i>serious</i> monkey business</p>",
  "created_at": "2011-10-29T20:45:28-05:00",
  "updated_at": "2011-10-29T20:45:28-05:00",

  "author": {
    "name": "David H.",
    "email_address": "'David Heinemeier Hansson' <david@heinemeierhansson.com>",
    "url": "http://example.com/users/1-david.json"
  },

  "visitors": 15,

  "tags": ['public'],

  "comments": [
    { "content": "Hello everyone!", "created_at": "2011-10-29T20:45:28-05:00" },
    { "content": "To you my good sir!", "created_at": "2011-10-29T20:47:28-05:00" }
  ],

  "attachments": [
    { "filename": "forecast.xls", "url": "http://example.com/downloads/forecast.xls" },
    { "filename": "presentation.pdf", "url": "http://example.com/downloads/presentation.pdf" }
  ]
}
```

To define attribute and structure names dynamically, use the `set!` method:

``` ruby
json.object! do
  json.set! :author do
    json.object! do
      json.set! :name, 'David'
    end
  end
end

# => { "author": { "name": "David" } }
```

To merge existing hash or array to current context:

``` ruby
hash = { author: { name: "David" } }
json.post do
  json.title "Merge HOWTO"
  json.merge! hash
end

# => "post": { "title": "Merge HOWTO", "author": { "name": "David" } }
```

Top level arrays can be handled directly.  Useful for index and other collection
actions.

``` ruby
json.array! @comments do |comment|
  next if comment.marked_as_spam_by?(current_user)

  json.object! do
    json.body comment.body
    json.author do
      json.first_name comment.author.first_name
      json.last_name comment.author.last_name
    end
  end
end

# => [ { "body": "great post...", "author": { "first_name": "Joe", "last_name": "Bloe" }} ]
```

You can also extract attributes from array directly.

``` ruby
# @people = People.all

json.array! @people, :id, :name

# => [ { "id": 1, "name": "David" }, { "id": 2, "name": "Jamie" } ]
```

You can either use TurboStreamer stand-alone or directly as an ActionView template
language. When required in Rails, you can create views ala show.json.streamer
(the json is already yielded):

``` ruby
# Any helpers available to views are available to the builder
json.object! do
  json.content format_content(@message.content)
  json.extract! @message, :created_at, :updated_at

  json.author do
    json.object! do
      json.name @message.creator.name.familiar
      json.email_address @message.creator.email_address_with_name
      json.url url_for(@message.creator, format: :json)
    end
  end

  if current_user.admin?
    json.visitors calculate_visitors(@message)
  end
end
```

You can use partials as well. The following will render the file
`views/comments/_comments.json.streamer`, and set a local variable
`comments` with all this message's comments, which you can use inside
the partial.

```ruby
json.partial! 'comments/comments', locals: { comments: @message.comments }
```

It's also possible to render collections of partials:

```ruby
json.array! @posts, partial: 'posts/post', as: :post

# or

json.partial! 'posts/post', collection: @posts, as: :post

# or

json.comments @post.comments, partial: 'comment/comment', as: :comment
```

The signature is `partial!(name, locals: nil, **render_options)`: the partial
name comes first, template locals go in `locals:`, and every other keyword is
passed to Action View as a render option.

```ruby
json.partial! 'posts/post', locals: { post: @post }  # a local named post
json.partial! 'posts/post', locale: :de              # picks _post.de.json.streamer
json.partial! 'posts/post', variants: :grid          # picks _post.json+grid.streamer
json.partial! 'posts/post', collection: @posts, as: :post
```
The one exception is `handlers:`, which is fixed to `[:streamer]`.

### Layouts

A `.json.streamer` layout can wrap the template. Call `json.yield!` where the
template's JSON should go:

```ruby
# app/views/layouts/application.json.streamer
json.object! do
  json.meta do
    json.object! { json.version 1 }
  end
  json.key! :data
  json.yield!
end

# app/views/posts/index.json.streamer
json.array! @posts, :id, :title

# => { "meta": { "version": 1 }, "data": [ { "id": 1, "title": "..." } ] }
```

The layout and the template share one builder, so the template writes straight
into the same stream at the point it is yielded — nothing is buffered into a
string and spliced back in. This works whether or not the response is streamed
with `render stream: true`; when it is, a large response still arrives in
chunks.

`json.yield!` goes anywhere a value goes, including inside an array:

```ruby
json.array! do
  json.child! { json.object! { json.first true } }
  json.child! { json.yield! }
end
```

A layout that only wraps is just the one call:

```ruby
json.yield!
```

A layout may yield more than once, and one that never yields renders without the
template — both as an ERB layout does. The difference is that ERB replays a
buffered string, whereas each `json.yield!` renders the template again, so
anything it does happens again too:

```ruby
json.array! do
  json.child! { json.yield! }
  json.child! { json.yield! }   # the template is rendered a second time
end
```

#### Why `json.yield!` and not `yield`

`yield` is a Ruby keyword that returns a value, and the template's JSON is never
a value here — it is written into the stream at the position the layout has
reached. Placing it therefore has to go through the builder, and `json.yield!`
matches the rest of the DSL, where the methods that write something end in `!`:
`object!`, `array!`, `child!`, `partial!`, `merge!`, `cache!`. A bare `yield` in
a `.json.streamer` layout raises `LocalJumpError` naming `json.yield!`.

#### Layouts are not ERB layouts

Two differences worth knowing:

* **The layout renders first**, and `json.yield!` renders the template it wraps.
  An ERB layout is the other way around: the template is rendered up front and
  the layout concatenates the resulting string. Reversing it is what lets the
  template write into the layout's builder instead of being encoded to a string
  and spliced back in — which neither encoder can do into a keyed slot.
* **There is one yield, and it has no name.** `content_for` / `provide` have no
  analogue, and a layout cannot ask for content the template defines later. In
  ERB that works because the layout runs in a Fiber and suspends until the
  template provides the key; here the layout calls the template directly, so
  there is nothing to suspend. A JSON document's shape is positional, so one
  yield in one place is generally what you want.

#### Layouts in API-only apps

`ActionController::API` does not include `ActionView::Layouts`, so a controller
inheriting from it renders the template and **silently skips the layout** — no
error, just a response missing whatever the layout wraps it in. Include the
module to turn layouts back on:

```ruby
module Api
  class BaseController < ActionController::API
    include ActionView::Layouts

    layout 'api'
  end
end
```

You can explicitly make TurboStreamer object return null if you want:

``` ruby
json.extract! @post, :id, :title, :content, :published_at
json.author do
  if @post.anonymous?
    json.null! # or json.nil!
  else
    json.object! do
      json.first_name @post.author_first_name
      json.last_name @post.author_last_name
    end
  end
end
```

Fragment caching is supported, it uses `Rails.cache` and works like caching in
HTML templates:

```ruby
json.object! do
  json.cache! ['v1', @person], expires_in: 10.minutes do
    json.extract! @person, :name, :age
  end
end
```

You can also conditionally cache a block by using `cache_if!` like this:

```ruby
json.object! do
  json.cache_if! !admin?, ['v1', @person], expires_in: 10.minutes do
    json.extract! @person, :name, :age
  end
end
```

Caching works both over a key and its value, and under a key as that key's
value:

```ruby
# the whole pair, or several pairs, as one fragment
json.object! do
  json.cache! :key do
    json.value! 'Cache this.'
  end
end

# or just the value
json.object! do
  json.key do
    json.cache! :key do
      json.value! 'Cache this.'
    end
  end
end
```

The two cache different bytes. Over the key, the fragment is a sequence of
pairs (`"key":"Cache this."`) and can cover several keys at once. Under the
key, it is a bare value (`"Cache this."`), which is not tied to the key it was
written for -- so the same fragment is reusable anywhere a value belongs, and
is interchangeable between the encoders.

Keys can be auto formatted using `key_format!`, this can be used to convert
keynames from the standard ruby_format to camelCase:

``` ruby
json.key_format! camelize: :lower
json.object! do
  json.first_name 'David'
end

# => { "firstName": "David" }
```

You can set this globally with the class method `key_format` (from inside your
environment.rb for example):

``` ruby
TurboStreamer.key_format camelize: :lower
```

Syntax Differences from Jbuilder
--------------------------------

- You must open JSON object or array if you want an object or array.
- You can directly output a value with `json.value! value`, this will
  allow you to put a number, string, or other JSON value if you wish
  to not have an object or array.
- The call syntax has been removed (eg. `json.(@person, :name, :age)`)
- Caching inside of a object must cache both the key and the value.

Backends
--------

Currently TurboStreamer supports [Wankel](https://github.com/malomalo/wankel) and
[Oj](https://github.com/ohler55/oj) for JSON encoding.

By default TurboStreamer will look for `Oj` and `Wankel` and use the first
available option.

You can also set the encoder when initializing:

```ruby
TurboStreamer.encode(encoder: :oj)
# Or
TurboStreamer.encode(encoder: :wankel)

# You can also pass the class
TurboStreamer.encode(encoder: TurboStreamer::WankelEncoder)

# Or your own encoder
TurboStreamer.encode(encoder: MyEncoder)
```

Setting the default encoder and options
---------------------------------------
If you need explicitly set the default:

```ruby
TurboStreamer.set_default_encoder(:json, :oj)
```

You can also set default options to pass to the encoder if needed:

```ruby
TurboStreamer.set_default_encoder(:json, :oj, buffer_size: 1_024)
```

You may also just set the default options for an encoder:

```ruby
TurboStreamer.set_default_encoder_options(:oj, buffer_size: 2_048)
```

The idea was to also support [MessagePack](http://msgpack.org/), hence requring
the mime type when setting a default encoder.

Implementing MessagePack would require a bit of work as you would need a change
in the protocol. We do not know how big an array or map/object will be when we
start emitting it and MessagePack require we know it. It seems like a relatively
small change, instead of a marker followed by number of lements there would be
a start marker followed by the elements and then an end marker.

All backends must have the following functions:

- `key(string)` Output a map key
- `value(value)` Output a value
- `map_open` Open a object/map
- `map_close` Close a object/map
- `array_open` Open an Array
- `array_close` Close an Array
- `flush` Flush any buffers
- `inject(string)` Inject a (usually cached) string into the output; instering any delimiters as needed.
- `capture(&block)` Capture the output of the block (w/o any delimiters)

Performance Benchmarks
----------------------

[Gnuplot](http://www.gnuplot.info) and [YAJL](http://lloyd.github.io/yajl/) are
required to run the benchmarks; YAJL is needed by
[`wankel`](https://github.com/malomalo/wankel), one of the encoders under test.
To install:

- `brew install gnuplot yajl` (MacOS)

The benchmark gems live in an optional Bundler group, so install them first:

    bundle config set with performance
    bundle install

To run the benchmarks: `bundle exec rake performance` (from the repository
root). It produces four reports — two document shapes, each run with fragment
caching off and on — and prints a table of each implementation's median i/s. The
reports below, and the i/s figures quoted in the text, come from one run on
macOS 26.5.1, Apple M5 Pro.

A third suite, vendored from alba, compares TurboStreamer against sixteen other
serializers rather than measuring document shapes. It carries its own bundle, so
it runs separately with `bundle exec rake performance:alba` — see
[performance/alba/README.md](performance/alba/README.md).

Both suites render live values before and after a cached fragment. A response
that is cacheable end to end would be cached at the controller rather than
rendered at all, so the case worth measuring is a cached fragment with live data
around it. With caching off, nothing is reused and the comparison is of the
builders themselves.

Caching is toggled with the `PERFORM_CACHING` environment variable, which each
library reads from the render context it is given (a fake controller in the
suites).

props_template additionally requires the render context to define
`cache_fragment_name`, which it calls unguarded where TurboStreamer and jbuilder
fall back to the bare key. The suites give it that method on a subclass rather
than on the shared context, so the other implementations keep the code path they
had before it was added.

All four implementations produce the same document — byte-identical output
(the two Oj-backed builders append a trailing newline), the same subtree cached
as the fragment, and the same live values rendered outside it. Each library
caches under its own key and namespace, so none can read another's entry, and
none touches the filesystem inside the measured loop.

Reading the numbers: these are microbenchmarks of the render layer. Every value
is precomputed before the measured loop, so builder overhead is nearly the
whole cost of an iteration. In an application, attribute access, type casting
and the rest of the request add the same absolute cost to every library, which
narrows every relative gap. Uncached, TurboStreamer's Oj encoder and
props_template — the two direct-to-encoder builders — are effectively tied and
trade the lead by document size: TurboStreamer ahead on the 22KB document
(1.15x), props_template on the 5MB one (1.11x). jbuilder trails both.

With a cached fragment the field splits by *what* each library caches, not by
how fast it builds. TurboStreamer and props_template both cache serialized
bytes and splice them into the output, so a hit costs a copy; jbuilder caches
the data structure and deserializes and re-serializes it on every hit. That
is worth an order of magnitude or more, and it puts props_template — the other
direct-to-encoder builder — in the same band as TurboStreamer rather than with
jbuilder. TurboStreamer is still the fastest cached in both suites — its
Oj encoder leads props_template by 1.36x on the 22KB document and 2.88x on the
5MB one. The GC panels are normalized per iteration, not per
second — implementations complete vastly different amounts of work in the same
five seconds, and a per-second axis would make the fastest one look the most
wasteful. The iterations axis is logarithmic for the same reason. RSS is a
process-level number and should be read against the iterations panel.

### rolftimmermans — 22KB document

An article with an author, 100 references and 100 comments. The article is the
cached fragment; `generated_at`, `request_id` and `total_comments` stay live.

The document comes from [rolftimmermans](https://github.com/rolftimmermans)'
[jbuilder#54](https://github.com/rails/jbuilder/pull/54) (2012).

<img src="https://raw.githubusercontent.com/malomalo/turbostreamer/master/performance/rolftimmermans/report-uncached.png" width="600" alt="rolftimmermans without caching: iterations/sec, GC and RSS for turbostreamer, props_template and jbuilder">

Rebuilt every iteration, the builders land close together and there is nothing
to stream at this size. TurboStreamer's Oj encoder leads at 3,911 i/s, with
props_template just behind at 3,392 (1.15x), then jbuilder at 2,573 and
TurboStreamer's Wankel encoder at 2,041. Each walks the same structure through
roughly 800 Ruby method calls per document.

<img src="https://raw.githubusercontent.com/malomalo/turbostreamer/master/performance/rolftimmermans/report-cached.png" width="600" alt="rolftimmermans with caching: iterations/sec, GC and RSS for turbostreamer, props_template and jbuilder">

With the fragment cached the ranking shifts and the field splits in two, along
the line of *what* each library caches. TurboStreamer (149,602 i/s) and
props_template (109,677) cache the fragment's serialized JSON and splice those
bytes into the output, so a hit costs a copy and no serialization. jbuilder
(6,643) caches the data structure, so a hit deserializes the cached objects and
re-serializes them into the response every time. That is a sixteen- to
twenty-three-fold difference between the two groups, against 1.36x between the
two byte-cachers.

### dirk — 5MB document

101 items each holding 101 sub-items, well past the size of a realistic
response, included for the large-payload and memory behaviour.

The document comes from [dirk](https://github.com/dirk), in
[a comment on jbuilder#289](https://github.com/rails/jbuilder/issues/289#issuecomment-146000448)
(2015) — a thread proposing caching improvements, which is why it is shaped
around a single large cacheable block.

<img src="https://raw.githubusercontent.com/malomalo/turbostreamer/master/performance/dirk/report-uncached.png" width="600" alt="dirk without caching: iterations/sec, GC and RSS for turbostreamer, props_template and jbuilder">

Rebuilt every iteration, the builders are again close, and closer than at 22KB:
here props_template (51.5 i/s) edges TurboStreamer's Oj encoder (46.1, 1.11x),
with jbuilder at 37.2 and the Wankel encoder at 29.9. Each walks the object
graph through roughly 51,000 Ruby-level DSL calls. Note the RSS panel, where
building the document costs every implementation several hundred MB.

<img src="https://raw.githubusercontent.com/malomalo/turbostreamer/master/performance/dirk/report-cached.png" width="600" alt="dirk with caching: iterations/sec, GC and RSS for turbostreamer, props_template and jbuilder">

With the fragment cached the same split appears and widens, because the larger
the cached fragment the more the re-serialization costs. The two byte-cachers
re-emit 5MB of cached bytes — TurboStreamer 10,165 i/s, props_template 3,527 —
while jbuilder (79.9) deserializes and re-serializes 5MB of cached objects,
leaving two orders of magnitude between the groups. The gap between the two
byte-cachers also opens up at this size, 2.88x against 1.36x on the 22KB
document. The RSS panel makes the deserialization cost visible: jbuilder climbs
to ~400MB while completing the *fewest* iterations, Marshal-loading the 5MB
cached hash on every hit, while TurboStreamer holds around 140MB while producing
two orders of magnitude more output.

### alba — TurboStreamer against sixteen other serializers

The two suites above measure document shapes against jbuilder and props_template. This one
is [alba](https://github.com/okuramasafumi/alba)'s own benchmark, vendored
unchanged apart from reporting both encoders, and it is the suite whose figures
get quoted at TurboStreamer: alba's README and props_template's both cite
results against **turbostreamer 1.11.0**, which predates 2.0.

100 posts with comments and commenter names, rendered from ActiveRecord. It is
`benchmark-ips` over seventeen serializers with no caching involved, so it
measures the builders themselves.

Run of 2026-09-10, ruby 4.0.5 +YJIT +PRISM, `Oj.optimize_rails` enabled, alba
4.0.0, props_template 1.0.1, oj 3.17.6, wankel 0.6.2.1:

```
                   panko:      918.9 i/s
        turbostreamer_oj:      725.6 i/s - 1.27x  slower
            barley_cache:      721.4 i/s - 1.27x  slower
          props_template:      683.9 i/s - 1.34x  slower
                  barley:      651.1 i/s - 1.41x  slower
                    alba:      635.5 i/s - 1.45x  slower
                jbuilder:      534.0 i/s - 1.72x  slower
                    rabl:      285.8 i/s - 3.21x  slower
    turbostreamer_wankel:      264.9 i/s - 3.47x  slower
```

`benchmark-memory`, same run:

```
               panko:     258858 allocated
      props_template:     457698 allocated - 1.77x more
    turbostreamer_oj:     466120 allocated - 1.80x more
turbostreamer_wankel:     550004 allocated - 2.12x more
                alba:     817961 allocated - 3.16x more
            jbuilder:     946201 allocated - 3.66x more
```

The Oj encoder is second only to panko, which is a C extension rather than a
builder DSL, and it is ahead of both props_template and alba — the reverse of
upstream's published ordering, which was measured against 1.11.0. Allocations
moved the same way: 641,720 for 1.11.0 in that table against 466,120 here, now
level with props_template.

**The Wankel encoder is a long way behind on this shape** — 265 i/s against 726,
and 550k allocated against 466k. Oj is the encoder TurboStreamer picks when both
are installed, and on these numbers that is the right default. Wankel also does
not escape `<`, `>` and `&`, which the railtie's `Oj` configuration does, so its
output is not safe to embed in a `<script>` tag without escaping it yourself.

Absolute numbers here are not comparable with upstream's, taken on different
hardware and a different Ruby — panko scores 919 i/s here against 1267 there —
so only the ordering within a single run means anything. Three consecutive runs
agreed on the ordering and to within 1.5% on `turbostreamer_oj` and 4% on
`turbostreamer_wankel`.

Special Thanks & Contributors
-----------------------------

TurboStreamer is a fork of [Jbuilder](https://github.com/rails/jbuilder), built of
what they have accopmlished and with out Jbuilder TurboStreamer would not be here today.
Thanks to everyone who's been a part of Jbuilder!

* David Heinemeier Hansson - http://david.heinemeierhansson.com/ - for writing Jbuidler!!
* Pavel Pravosud - http://pavel.pravosud.com/ - for maintaing and pushing Jbuilder forward

And to everyone who has contributed to TurboStreamer since the fork:

* [PikachuEXE](https://github.com/PikachuEXE) - for writing the Oj encoder, implementing
  `merge!`, fixing the caching output bugs, and adding the RABL benchmark
* [Stephen Demjanenko](https://github.com/sdemjanenko) - for streaming without requiring a
  layout, and for tuning the Oj `StreamWriter` buffer size

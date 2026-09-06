# alba's benchmark suite

Vendored from [alba](https://github.com/okuramasafumi/alba)'s `benchmark/`
directory (MIT, see `LICENSE.alba.txt`). `prep.rb`, `collection.rb`,
`single_resource.rb` and `views/` are upstream's, unmodified — the point is to
stay comparable with the numbers alba and props_template publish from it.

It is here because this is the suite whose figures get quoted at TurboStreamer.
props_template's README and alba's own README both cite results against
**turbostreamer 1.11.0**, which predates 2.0 and the hot-path work after it.
The `Gemfile` here points `turbostreamer` at this working tree so the suite
measures the current code.

This suite is shaped differently from `dirk/` and `rolftimmermans/`: it is
benchmark-ips over ~17 serializers against an in-memory SQLite/ActiveRecord
dataset, not an Analyzer plot, so `rake performance` does not run it.

## Running it

The gems live in their own bundle, separate from the repo's:

```
BUNDLE_GEMFILE=performance/alba/Gemfile bundle install
bundle exec rake performance:alba
```

Or directly, which is how upstream documents the four configurations:

```
cd performance/alba
BUNDLE_GEMFILE=Gemfile bundle exec ruby collection.rb                     # Oj.optimize_rails + YJIT
BUNDLE_GEMFILE=Gemfile NO_YJIT=1 bundle exec ruby collection.rb
BUNDLE_GEMFILE=Gemfile NO_OJ_OPTIMIZE_RAILS=1 bundle exec ruby collection.rb
BUNDLE_GEMFILE=Gemfile NO_YJIT=1 NO_OJ_OPTIMIZE_RAILS=1 bundle exec ruby collection.rb
```

`collection.rb` is the one the published tables come from. `single_resource.rb`
runs the same comparison over one record.

Both scripts end with a `benchmark-memory` pass as well as `benchmark-ips`.

## Reading the results

Report whatever it prints, and quote the configuration alongside any number.
The configurations differ enough to change the ordering — upstream's own tables
show turbostreamer moving relative to alba depending on YJIT and
`Oj.optimize_rails` — so never compare across configurations, and never across
machines.

### Run of 2026-09-05, `collection.rb`, turbostreamer 2.0.0 + unreleased

Apple M5 Pro, ruby 4.0.5 +PRISM, YJIT enabled, `Oj.optimize_rails` enabled,
alba 4.0.0, props_template 1.0.1.

```
                   panko:      901.0 i/s
           turbostreamer:      726.3 i/s - 1.24x  slower
            barley_cache:      715.1 i/s - 1.26x  slower
          props_template:      676.8 i/s - 1.33x  slower
                    alba:      657.7 i/s - 1.37x  slower
                  barley:      645.1 i/s - 1.40x  slower
                jbuilder:      533.6 i/s - 1.69x  slower
```

`benchmark-memory`, same run:

```
               panko:     258858 allocated
      props_template:     457698 allocated - 1.77x more
       turbostreamer:     465920 allocated - 1.80x more
                alba:     817961 allocated - 3.16x more
            jbuilder:     946201 allocated - 3.66x more
```

Two things worth noting, both bounded:

* **Ordering has changed.** Upstream's published table has turbostreamer behind
  both props_template and alba; here it is second only to panko, ahead of both.
  Allocations moved too — 641,720 for 1.11.0 in upstream's table, 465,920 here,
  now level with props_template. Reproduced across three runs (726–742 i/s).
* **The absolute numbers are not comparable to upstream's**, which were taken on
  an M4 Pro with ruby 3.4.8 and alba 3.10.0. panko scores 901 i/s here against
  1267 there, so this machine is slower overall — only the ordering *within* a
  run is a fair comparison, and that is the only claim to make from it.

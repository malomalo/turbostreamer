# alba's benchmark suite

Vendored from [alba](https://github.com/okuramasafumi/alba)'s `benchmark/`
directory (MIT, see `LICENSE.alba.txt`). `prep.rb` and `views/` are upstream's,
unmodified — the point is to stay comparable with the numbers alba and
props_template publish from it.

`collection.rb` and `single_resource.rb` carry one change from upstream: the
turbostreamer serializer takes an encoder and is reported twice, once on Oj and
once on Wankel, rather than once on whatever the global default happens to be.
Every other serializer is untouched, so the comparison still holds.

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

### Run of 2026-09-10, `collection.rb`, turbostreamer 2.0.0 + unreleased

Apple M5 Pro, ruby 4.0.5 +YJIT +PRISM, YJIT enabled, `Oj.optimize_rails`
enabled, alba 4.0.0, props_template 1.0.1, oj 3.17.6, wankel 0.6.2.1.

```
                   panko:      921.3 i/s
           turbostreamer:      734.3 i/s - 1.25x  slower
            barley_cache:      720.9 i/s - 1.28x  slower
          props_template:      672.7 i/s - 1.37x  slower
                    alba:      655.8 i/s - 1.40x  slower
                  barley:      645.1 i/s - 1.43x  slower
                jbuilder:      537.5 i/s - 1.71x  slower
                    rabl:      287.8 i/s - 3.20x  slower
    turbostreamer_wankel:      253.8 i/s - 3.63x  slower
```

`benchmark-memory`, same run:

```
               panko:     258858 allocated
      props_template:     457698 allocated - 1.77x more
       turbostreamer:     466120 allocated - 1.80x more
turbostreamer_wankel:     550004 allocated - 2.12x more
                alba:     817961 allocated - 3.16x more
            jbuilder:     946201 allocated - 3.66x more
```

Three things worth noting, all bounded:

* **`turbostreamer` here is the Oj encoder; `turbostreamer_wankel` is Wankel.**
  They are reported separately, as `dirk/` and `rolftimmermans/` do, because the
  gap is not small: 734 i/s against 254, and 466k allocated against 550k. A
  figure quoted as "turbostreamer" without saying which encoder produced it is
  not a figure about this library.
* **Ordering has changed** against upstream's published table, which has
  turbostreamer behind both props_template and alba; on Oj it is second only to
  panko, ahead of both. Allocations moved too — 641,720 for 1.11.0 in upstream's
  table, 466,120 here, now level with props_template.
* **The absolute numbers are not comparable to upstream's**, which were taken on
  an M4 Pro with ruby 3.4.8 and alba 3.10.0. panko scores 921 i/s here against
  1267 there, so this machine is slower overall — only the ordering *within* a
  run is a fair comparison, and that is the only claim to make from it.

Two consecutive runs, on a machine at load average ~6, agreed on the ordering
and to within 1% on every entry except `turbostreamer_wankel`, which moved 4%
(264 → 254 i/s). Re-run before quoting anything narrower than the ordering.

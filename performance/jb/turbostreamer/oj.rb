require 'turbostreamer/railtie'
TurboStreamer::Railtie.initializers.each(&:run)
TurboStreamer.set_default_encoder(:json, :oj)

set_view_path({
  'index.json.streamer'    => "json.object! do\njson.comments do\njson.array! @comments, partial: 'comment', as: :comment\nend\nend",
  '_comment.json.streamer'  => "json.object! do\njson.body comment.body\nend"
})

# Everthing before this is run once initially, after is the test
__SETUP__

render({template: 'index'})
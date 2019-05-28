require 'oj'
MultiJson.use :oj

require 'active_support/core_ext'
require 'action_view/rendering'
require 'action_controller/api/api_rendering'
require 'jb/railtie'
Jb::Railtie.initializers.each(&:run)

set_view_path({
  'index.json.jb'    => "{comments: render(partial: 'comment', collection: @comments, as: 'comment')}",
  '_comment.json.jb'  => '{body: comment.body}'
})

# Everthing before this is run once initially, after is the test
__SETUP__

render({template: 'index'})
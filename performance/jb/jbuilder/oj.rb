require 'jbuilder'
# require 'oj'
# require 'multi_json'
# MultiJson.use :oj

require 'active_support/core_ext'
require 'action_view/rendering'
require 'action_controller/api/api_rendering'
require 'jbuilder/railtie'
Jbuilder::Railtie.initializers.each(&:run)

set_view_path({
  'index.json.jbuilder'    => "json.comments do\njson.partial! 'comment', collection: @comments, as: 'comment'\nend",
  '_comment.json.jbuilder'  => "json.body comment.body"
})

# Everthing before this is run once initially, after is the test
__SETUP__

render({template: 'index'})
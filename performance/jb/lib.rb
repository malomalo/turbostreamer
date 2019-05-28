$LOAD_PATH << File.expand_path('../lib', __FILE__)

require 'multi_json'
require 'rails'
require 'action_view'
require 'action_view/testing/resolvers'
require 'action_view/renderer/template_renderer'
require 'action_view/renderer/partial_renderer'

class Comment
  attr_accessor :id, :body
  def initialize(id, comment)
    @id = id
    @body = comment
  end
end

def set_view_path(views)
  resolver = ActionView::FixtureResolver.new(views)
  view_paths = ActionView::PathSet.new([resolver])
  
  $controller = ActionView::TestCase::TestController.new
  $controller.lookup_context.instance_variable_set(:@view_paths, view_paths)
end

def render(options = {}, local_assigns = {}, &block)
  view = $controller.view_context
  view.output_buffer = ActiveSupport::SafeBuffer.new("")

  view.render(options, local_assigns)
end

@comments = 1.upto(100).map { |i| Comment.new(i, "comment #{i}") }

__END__



ActionView::TemplateRenderer.new($controller.lookup_context).render({}, {template: 'index'})

  context, options
)

pr = ActionView::PartialRenderer.new(lookup_context)
pr.send(:setup, @context, options, nil)
template = pr.send(:find_partial)

locals = options[:locals]
array! options[:collection] do |member|
  locals[as] = member
  template.render(@context, locals)
end

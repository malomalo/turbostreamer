require 'oj'
require 'rabl'

SOURCE = File.read(File.expand_path("./performance/rolftimmermans/rabl/views/template.rabl"))

__SETUP__

Rabl::Renderer.new(SOURCE, nil, format: :json).render

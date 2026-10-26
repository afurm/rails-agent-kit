# A tiny mountable engine, so the routes corpus covers "Routes for <Engine>" sections.
module StatusEngine
  class Engine < ::Rails::Engine
    isolate_namespace StatusEngine
  end
end

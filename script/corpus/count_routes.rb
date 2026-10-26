# frozen_string_literal: true

# Prints how many routes `bin/rails routes --expanded` lists for the booted app, counted from the route set
# itself: the app's routes plus the routes of every mounted engine (each engine is listed once), leaving out
# the routes Rails itself hides (internal routes and the asset server mount).
# Run with `bin/rails runner script/corpus/count_routes.rb`.
require "json"

visible = ->(route_set) { route_set.routes.reject { |r| ActionDispatch::Routing::RouteWrapper.new(r).internal? } }
app_routes = visible.call(Rails.application.routes)
engines = app_routes.filter_map { |r| r.app.app if r.app.respond_to?(:app) && r.app.app.respond_to?(:routes) && r.app.engine? }
engines = engines.uniq

out = {
  routes: app_routes.size + engines.sum { |e| visible.call(e.routes).size },
  engines: engines.to_h { |e| [e.name, visible.call(e.routes).size] }
}
puts JSON.pretty_generate(out)

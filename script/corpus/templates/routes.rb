require "sidekiq/web"

StatusEngine::Engine.routes.draw do
  get "/", to: "status#show", as: :status
  get "/details", to: "status#show", as: :details
end

Rails.application.routes.draw do
  devise_for :accounts
  resources :posts
  namespace :admin do
    resources :reports, only: %i[index show]
  end
  resource :session if defined?(SessionsController)
  resources :passwords, param: :token if defined?(PasswordsController)

  mount Sidekiq::Web => "/sidekiq"
  mount StatusEngine::Engine => "/status"
  mount ->(_env) { [200, { "content-type" => "text/plain" }, ["ok"]] }, at: "/ping"

  get "up" => "rails/health#show", as: :rails_health_check
  root "posts#index"
end

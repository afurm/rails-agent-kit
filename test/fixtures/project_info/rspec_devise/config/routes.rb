require "sidekiq/web"

Rails.application.routes.draw do
  devise_for :users
  authenticate :user, ->(user) { user.admin? } do
    mount Sidekiq::Web => "/sidekiq"
  end
  resources :posts
  get "up" => "rails/health#show", as: :rails_health_check
  root "posts#index"
end

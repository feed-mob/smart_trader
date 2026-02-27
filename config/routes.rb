Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Sidekiq Web UI (add authentication in production!)
  require "sidekiq/web"
  mount Sidekiq::Web => "/sidekiq"

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Authentication routes
  get "login", to: "sessions#new", as: :login
  post "auth/google/callback", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  # Defines the root path route ("/")
  root "home#index"

  # API routes (Phase 4)
  namespace :api do
    namespace :v1 do
      resources :assets, only: [:index, :show] do
        get :snapshots, on: :member
        get :latest, on: :member
      end
      # Custom collection routes
      get :top_by_volume, to: "assets#top_by_volume"
      get :health, to: "assets#health"
      post :collect, to: "assets#collect"
    end
  end

  # Trader management
  resources :traders
end

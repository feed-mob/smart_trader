require "sidekiq/web"

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

  # Market Assets (Phase 6) - Use market_assets path to avoid conflict with Rails assets pipeline
  resources :market_assets, controller: 'assets', only: [:index, :show] do
    get :analysis, on: :member
  end

  # Favicon - suppress routing error
  get "favicon.ico", to: proc { [204, {}, [""]] }

  # Defines the root path route ("/")
  root "home#index"

  # API routes (Phase 4 & 5)
  namespace :api do
    namespace :v1 do
      resources :assets, only: [:index, :show] do
        get :snapshots, on: :member
        get :latest, on: :member
        get :analyze, on: :member
        get :signal, on: :member
        # Custom collection and analysis routes
        collection do
          get :health, to: "assets#health"
          post :collect, to: "assets#collect"
        end
      end
    end
  end

  # Trader management
  resources :traders do
    resource :allocation_preview, only: [:show] do
      get :recommendation, on: :collection
    end
  end

  # AI Analysis
  get 'ai_analysis', to: 'ai_analysis#new', as: :new_ai_analysis
  post 'ai_analysis', to: 'ai_analysis#create', as: :ai_analysis
  get 'ai_analysis/result', to: 'ai_analysis#show', as: :ai_analysis_result
  post 'ai_analysis/quick', to: 'ai_analysis#quick_analysis', as: :quick_ai_analysis

  # Admin namespace
  namespace :admin do
    resources :factor_definitions do
      member do
        post :toggle
      end
      collection do
        get :matrix
        get :correlations
      end
    end

    resources :trading_signals, only: %i[index show] do
      collection do
        post :generate
        post :generate_all
      end
    end
  end
end

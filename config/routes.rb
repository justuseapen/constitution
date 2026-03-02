Rails.application.routes.draw do
  devise_for :users

  resources :projects do
    resources :documents do
      collection do
        post :import
      end
    end
    resources :blueprints
    resources :work_orders do
      member do
        post :execute
        post :cancel_execution
      end
    end
    resources :feedback_items, only: [ :index, :show, :update ] do
      member do
        post :create_work_order
      end
    end
    resources :repositories, only: [ :create, :destroy ], controller: "project_repositories" do
      member do
        post :retry_index
      end
    end
  end

  resource :onboarding, only: [ :new, :create ], controller: "onboarding"

  resource :graph_explorer, only: [ :show ], controller: "graph_explorer" do
    get :neighbors
    get :impact_analysis
    get :root_nodes
  end

  resources :agent_chats, only: [ :index, :create ]

  resources :systems do
    member do
      get :architecture
      post :generate_diagram
    end
  end

  resources :notifications, only: [ :index ] do
    collection do
      post :mark_read
      get :unread_count
    end
  end

  namespace :api do
    namespace :v1 do
      resources :feedback, only: [ :create ], controller: "feedback"
    end
  end

  root "projects#index"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end

Rails.application.routes.draw do
  devise_for :users

  resources :projects do
    resources :documents
    resources :blueprints
    resources :work_orders
    resources :feedback_items, only: [:index, :show, :update] do
      member do
        post :create_work_order
      end
    end
  end

  resources :agent_chats, only: [:create]

  resources :systems

  resources :notifications, only: [:index] do
    collection do
      post :mark_read
      get :unread_count
    end
  end

  namespace :api do
    namespace :v1 do
      resources :feedback, only: [:create], controller: "feedback"
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

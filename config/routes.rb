Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "conversations#index"

  resources :conversations, only: %i[index show update] do
    get :sidebar, on: :collection
    resources :messages, only: :index
    resources :runs, only: :create
    resource :favorite, only: %i[create destroy]
  end
  resources :messages, only: :show do
    get :image, on: :member
    resource :save, only: %i[create destroy]
  end
  get "saved", to: "saves#index", as: :saved_messages
  resources :transcripts, only: :show
  resources :runs, only: [] do
    post :cancel, on: :member
  end
  resource :scan, only: :create
  resource :search, only: :show
  resource :settings, only: %i[edit update]
end

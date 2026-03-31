require "sidekiq/web"

Rails.application.routes.draw do
  # Hotwire Dashboard
  root "dashboard#index"

  # Sidekiq Web UI (protected)
  mount Sidekiq::Web => "/sidekiq"

  # ActionCable
  mount ActionCable.server => "/cable"

  # API v1
  namespace :api do
    namespace :v1 do
      resources :watchlists, only: %i[index create destroy] do
        member do
          get :quote
        end
      end

      resources :alerts, only: %i[index create update destroy] do
        collection do
          get :history
        end
      end

      resource :analysis, only: [], controller: "analysis" do
        member do
          get :overview
          get :technical
          get :news
        end
        collection do
          get :briefing
        end
      end

      resource :settings, only: %i[show update], controller: "settings" do
        post :test_notification
        post :mute
        post :unmute
      end

      resource :health, only: :show, controller: "health" do
        get :metrics
      end
    end
  end
end

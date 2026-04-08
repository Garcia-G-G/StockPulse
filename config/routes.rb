require "sidekiq/web"

if Rails.env.production? && (ENV["SIDEKIQ_USER"].blank? || ENV["SIDEKIQ_PASSWORD"].blank?)
  Rails.logger.warn("SIDEKIQ_USER and SIDEKIQ_PASSWORD must be set in production!")
end

Sidekiq::Web.use(Rack::Auth::Basic) do |user, password|
  expected_user = ENV.fetch("SIDEKIQ_USER") { Rails.env.production? ? nil : "admin" }
  expected_pass = ENV.fetch("SIDEKIQ_PASSWORD") { Rails.env.production? ? nil : "password" }
  next false unless expected_user && expected_pass

  ActiveSupport::SecurityUtils.secure_compare(user, expected_user) &&
    ActiveSupport::SecurityUtils.secure_compare(password, expected_pass)
end

Rails.application.routes.draw do
  # Devise authentication
  devise_for :users, path: "", path_names: {
    sign_in: "login",
    sign_out: "logout",
    sign_up: "signup",
    password: "forgot-password"
  }, controllers: {
    registrations: "users/registrations",
    sessions: "users/sessions",
    passwords: "users/passwords"
  }

  # Root routing based on auth state
  unauthenticated :user do
    root "landing#index"
    get "/api/search", to: "landing#search"
    get "/quote/:symbol", to: "quotes#show", as: "public_quote"
  end

  authenticated :user do
    root "dashboard#index", as: :authenticated_root
  end

  # Onboarding
  get "/onboarding", to: "onboarding#show"
  post "/onboarding/step/:step", to: "onboarding#update", as: "onboarding_step"

  # Profile
  get "/profile", to: "profile#show"
  patch "/profile", to: "profile#update"

  # Sidekiq Web UI
  mount Sidekiq::Web => "/sidekiq"

  # ActionCable
  mount ActionCable.server => "/cable"

  # API v1
  namespace :api do
    namespace :v1 do
      resource :me, only: :show, controller: "me"

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

      scope "analysis", controller: "analysis" do
        get "briefing", action: :briefing, as: :analysis_briefing
        get ":id/overview", action: :overview, as: :analysis_overview
        get ":id/technical", action: :technical, as: :analysis_technical
        get ":id/news", action: :news, as: :analysis_news
      end

      resource :settings, only: %i[show update], controller: "settings" do
        post :test_notification
        post :mute
        post :unmute
      end

      resource :health, only: :show, controller: "health" do
        get :metrics
      end

      resources :prices, only: [] do
        collection do
          get :current
          get :stream_status
        end
        member do
          get :history
        end
      end
    end
  end
end

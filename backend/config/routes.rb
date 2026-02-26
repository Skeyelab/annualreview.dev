Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # Redirect root to frontend so opening the API URL shows the app (dev: 5173, prod: FRONTEND_URL).
  root to: redirect(ENV.fetch("FRONTEND_URL", "http://localhost:5173"))

  namespace :api do
    get    "auth/github",          to: "auth#github"
    get    "auth/github/callback", to: "auth#callback"
    get    "auth/me",              to: "auth#me"
    delete "auth/logout",          to: "auth#logout"
    post   "auth/logout",          to: "auth#logout"

    post "collect",  to: "collect#create"
    post "generate", to: "generate#create"
    get  "jobs",     to: "jobs#index"
    get  "jobs/:id", to: "jobs#show"

    scope "users/me" do
      get    "years",              to: "review_years#index"
      get    "years/:year",        to: "review_years#show"
      patch  "years/:year",        to: "review_years#update"
      get    "years/:year/review", to: "review_years#review"
    end
  end

  # OmniAuth callback route
  match "/auth/github/callback", to: "api/auth#callback", via: [ :get, :post ]
end

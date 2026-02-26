Rails.application.config.middleware.use OmniAuth::Builder do
  provider :github,
    ENV.fetch("GITHUB_CLIENT_ID", ""),
    ENV.fetch("GITHUB_CLIENT_SECRET", ""),
    scope: "repo"
end

OmniAuth.config.allowed_request_methods = [:get, :post]
OmniAuth.config.silence_get_warning = true

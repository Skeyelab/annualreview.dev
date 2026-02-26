require "rails_helper"

RSpec.describe "Collect API", type: :request do
  let(:user) { User.create!(github_id: 42, login: "testuser", access_token: "ghp_test") }

  before do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github", uid: user.github_id.to_s,
      info: { nickname: user.login },
      credentials: { token: "ghp_test" }
    )
    get "/auth/github/callback"
  end

  describe "POST /api/collect" do
    it "returns 400 without required params" do
      post "/api/collect", params: {}, as: :json
      expect(response).to have_http_status(:bad_request)
    end

    it "returns 202 and enqueues collect job" do
      post "/api/collect", params: { start_date: "2025-01-01", end_date: "2025-12-31" }, as: :json
      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      expect(body["job_id"]).to be_present
    end
  end
end

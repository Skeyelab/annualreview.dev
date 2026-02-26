require "rails_helper"

RSpec.describe "Review Years API", type: :request do
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

  describe "GET /api/users/me/years" do
    it "returns empty array when no years" do
      get "/api/users/me/years"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq([])
    end

    it "returns user's review years" do
      user.review_years.create!(year: 2025)
      get "/api/users/me/years"
      body = JSON.parse(response.body)
      expect(body.length).to eq(1)
      expect(body.first["year"]).to eq(2025)
    end
  end

  describe "GET /api/users/me/years/:year" do
    it "returns 404 for non-existent year" do
      get "/api/users/me/years/2025"
      expect(response).to have_http_status(:not_found)
    end

    it "returns the review year" do
      user.review_years.create!(year: 2025, goals: "Ship faster")
      get "/api/users/me/years/2025"
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["year"]).to eq(2025)
      expect(body["goals"]).to eq("Ship faster")
    end
  end

  describe "PATCH /api/users/me/years/:year" do
    it "creates year if it doesn't exist" do
      patch "/api/users/me/years/2025", params: { goals: "Grow as tech lead" }, as: :json
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["year"]).to eq(2025)
      expect(body["goals"]).to eq("Grow as tech lead")
      expect(user.review_years.count).to eq(1)
    end

    it "updates goals on existing year" do
      user.review_years.create!(year: 2025, goals: "Old goals")
      patch "/api/users/me/years/2025", params: { goals: "New goals" }, as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["goals"]).to eq("New goals")
    end

    it "updates timeframe" do
      patch "/api/users/me/years/2025", params: { start_date: "2025-04-01", end_date: "2026-03-31" }, as: :json
      body = JSON.parse(response.body)
      expect(body["start_date"]).to eq("2025-04-01")
      expect(body["end_date"]).to eq("2026-03-31")
    end
  end

  describe "unauthenticated access" do
    it "returns 401" do
      delete "/api/auth/logout"
      get "/api/users/me/years"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end

require "rails_helper"

RSpec.describe "Generate API", type: :request do
  let(:user) { User.create!(github_id: 42, login: "testuser", access_token: "ghp_test") }
  let(:valid_evidence) do
    {
      timeframe: { start_date: "2025-01-01", end_date: "2025-12-31" },
      contributions: [
        { id: "org/repo#1", type: "pull_request", title: "PR", url: "https://github.com/org/repo/pull/1", repo: "org/repo" }
      ]
    }
  end

  before do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github", uid: user.github_id.to_s,
      info: { nickname: user.login },
      credentials: { token: "ghp_test" }
    )
    get "/auth/github/callback"
  end

  describe "POST /api/generate (by year)" do
    it "returns 404 when no review year exists" do
      post "/api/generate", params: { year: 2025 }, as: :json
      expect(response).to have_http_status(:not_found)
    end

    it "returns 422 when no evidence" do
      user.review_years.create!(year: 2025)
      post "/api/generate", params: { year: 2025 }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 202 and enqueues generate job with evidence" do
      user.review_years.create!(year: 2025, evidence: valid_evidence)
      post "/api/generate", params: { year: 2025 }, as: :json
      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      expect(body["job_id"]).to be_present
    end
  end

  describe "POST /api/generate (evidence in body — 1:1 Node parity)" do
    it "returns 400 for invalid evidence (missing contributions)" do
      post "/api/generate", params: { timeframe: { start_date: "2025-01-01", end_date: "2025-12-31" } }, as: :json
      expect(response).to have_http_status(:bad_request)
      body = JSON.parse(response.body)
      expect(body["error"]).to match(/invalid evidence/i)
    end

    it "returns 400 for invalid evidence (missing timeframe)" do
      post "/api/generate", params: { contributions: [] }, as: :json
      expect(response).to have_http_status(:bad_request)
    end

    it "returns 202 and enqueues job when full evidence is posted" do
      post "/api/generate", params: valid_evidence, as: :json
      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      expect(body["job_id"]).to be_present
    end
  end

  describe "GET /api/users/me/years/:year/review" do
    it "returns 404 when no review year" do
      get "/api/users/me/years/2025/review"
      expect(response).to have_http_status(:not_found)
    end

    it "returns pipeline_result and markdown" do
      ry = user.review_years.create!(year: 2025, pipeline_result: {
        themes: { themes: [ { theme_id: "t1", theme_name: "Reliability" } ] },
        bullets: { top_10_bullets_overall: [] },
        stories: { stories: [] },
        self_eval: { sections: {} }
      })
      get "/api/users/me/years/2025/review"
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["pipeline_result"]).to be_present
      expect(body["markdown"]).to include("# Annual Review Report")
    end

    it "returns 204 when no pipeline result yet" do
      user.review_years.create!(year: 2025)
      get "/api/users/me/years/2025/review"
      expect(response).to have_http_status(:no_content)
    end
  end
end

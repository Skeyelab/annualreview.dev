require "rails_helper"

RSpec.describe "Jobs API", type: :request do
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

  describe "GET /api/jobs/:id" do
    it "returns 404 for unknown job" do
      get "/api/jobs/nonexistent"
      expect(response).to have_http_status(:not_found)
    end

    it "returns cached job payload" do
      Rails.cache.write("job:abc123", { status: "done", result: { foo: 1 } })
      get "/api/jobs/abc123"
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("done")
    end
  end

  describe "GET /api/jobs (latest)" do
    it "returns { latest: null } when no jobs exist" do
      get "/api/jobs"
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["latest"]).to be_nil
    end

    it "returns the most recent job for the current user" do
      Rails.cache.write("job:old", { status: "done", result: { n: 1 } })
      Rails.cache.write("job:new", { status: "done", result: { n: 2 } })
      user.update!(latest_job_id: "new")

      get "/api/jobs"
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["latest"]).to be_present
      expect(body["latest"]["status"]).to eq("done")
      expect(body["latest"]["result"]["n"]).to eq(2)
    end
  end
end

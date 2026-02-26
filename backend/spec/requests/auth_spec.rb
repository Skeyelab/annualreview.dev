require "rails_helper"

RSpec.describe "Auth", type: :request do
  before do
    OmniAuth.config.test_mode = true
  end

  describe "GET /api/auth/github" do
    it "redirects to OmniAuth GitHub path" do
      get "/api/auth/github"
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "GET /auth/github/callback (OmniAuth callback)" do
    let!(:mock_auth) do
      OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
        provider: "github",
        uid: "42",
        info: { nickname: "testuser" },
        credentials: { token: "ghp_test_token" }
      )
    end

    it "creates user and sets session" do
      expect { get "/auth/github/callback" }.to change(User, :count).by(1)
      expect(response).to have_http_status(:redirect)
      user = User.last
      expect(user.github_id).to eq(42)
      expect(user.login).to eq("testuser")
    end

    it "finds existing user on repeat login" do
      User.create!(github_id: 42, login: "testuser")
      expect { get "/auth/github/callback" }.not_to change(User, :count)
    end
  end

  describe "GET /api/auth/me" do
    context "when not authenticated" do
      it "returns 401" do
        get "/api/auth/me"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when authenticated" do
      before do
        OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
          provider: "github",
          uid: "42",
          info: { nickname: "testuser" },
          credentials: { token: "ghp_test_token" }
        )
        get "/auth/github/callback"
      end

      it "returns current user" do
        get "/api/auth/me"
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["login"]).to eq("testuser")
        expect(body["github_id"]).to eq(42)
      end
    end
  end

  describe "DELETE /api/auth/logout" do
    it "clears session and returns 200" do
      delete "/api/auth/logout"
      expect(response).to have_http_status(:ok)
    end

    it "clears current user after logout" do
      OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
        provider: "github", uid: "42",
        info: { nickname: "testuser" },
        credentials: { token: "ghp_test" }
      )
      get "/auth/github/callback"
      delete "/api/auth/logout"
      get "/api/auth/me"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end

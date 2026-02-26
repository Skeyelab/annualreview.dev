require "rails_helper"

RSpec.describe GithubCollector do
  let(:token) { "ghp_test" }
  let(:start_date) { "2025-01-01" }
  let(:end_date) { "2025-12-31" }

  let(:viewer_response) do
    { data: { viewer: { login: "testuser" } } }
  end

  let(:search_response) do
    { data: { search: {
      edges: [
        { node: {
          __typename: "PullRequest",
          number: 42, title: "Fix auth bug", body: "Fixes the auth flow",
          url: "https://github.com/org/repo/pull/42",
          mergedAt: "2025-06-15T12:00:00Z",
          additions: 100, deletions: 20, changedFiles: 5,
          baseRepository: { nameWithOwner: "org/repo" },
          labels: { nodes: [ { name: "bug" } ] },
          reviewThreads: { totalCount: 2 },
          reviews: { nodes: [
            { id: "R_1", body: "LGTM", state: "APPROVED", submittedAt: "2025-06-15T13:00:00Z", url: "https://github.com/org/repo/pull/42#pullrequestreview-1" }
          ] }
        } }
      ],
      pageInfo: { endCursor: nil, hasNextPage: false }
    } } }
  end

  before do
    stub_request(:post, "https://api.github.com/graphql")
      .to_return(
        { body: viewer_response.to_json, headers: { "Content-Type" => "application/json" } },
        { body: search_response.to_json, headers: { "Content-Type" => "application/json" } }
      )
  end

  describe "#collect_raw" do
    it "returns timeframe, pull_requests, and reviews" do
      result = described_class.new(token:, start_date:, end_date:).collect_raw
      expect(result[:timeframe]).to eq({ start_date: "2025-01-01", end_date: "2025-12-31" })
      expect(result[:pull_requests].length).to eq(1)
      pr = result[:pull_requests].first
      expect(pr[:number]).to eq(42)
      expect(pr[:title]).to eq("Fix auth bug")
      expect(pr[:base][:repo][:full_name]).to eq("org/repo")
      expect(result[:reviews].length).to eq(1)
      review = result[:reviews].first
      expect(review[:id]).to eq("R_1")
      expect(review[:state]).to eq("APPROVED")
    end
  end
end

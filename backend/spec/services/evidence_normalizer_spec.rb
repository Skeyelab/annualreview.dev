require "rails_helper"

RSpec.describe EvidenceNormalizer do
  describe ".normalize" do
    let(:raw) do
      {
        timeframe: { start_date: "2025-01-01", end_date: "2025-12-31" },
        pull_requests: [
          {
            number: 42, title: "Fix auth bug", body: "Fixes the auth flow",
            html_url: "https://github.com/org/repo/pull/42",
            merged_at: "2025-06-15T12:00:00Z",
            base: { repo: { full_name: "org/repo" } },
            labels: [{ name: "bug" }],
            changed_files: 5, additions: 100, deletions: 20,
            review_comments: 2
          }
        ],
        reviews: [
          {
            id: "R_1", body: "LGTM", state: "APPROVED",
            submitted_at: "2025-06-15T13:00:00Z",
            html_url: "https://github.com/org/repo/pull/42#pullrequestreview-1",
            repository: { full_name: "org/repo" },
            pull_number: 42
          }
        ]
      }
    end

    it "returns evidence with timeframe and contributions" do
      result = described_class.normalize(raw, "2025-01-01", "2025-12-31")
      expect(result[:timeframe]).to eq({ start_date: "2025-01-01", end_date: "2025-12-31" })
      expect(result[:contributions].length).to eq(2)
    end

    it "normalizes PRs with correct fields" do
      result = described_class.normalize(raw)
      pr = result[:contributions].find { |c| c[:type] == "pull_request" }
      expect(pr[:id]).to eq("org/repo#42")
      expect(pr[:title]).to eq("Fix auth bug")
      expect(pr[:url]).to eq("https://github.com/org/repo/pull/42")
      expect(pr[:repo]).to eq("org/repo")
      expect(pr[:merged_at]).to eq("2025-06-15T12:00:00Z")
      expect(pr[:labels]).to eq(["bug"])
      expect(pr[:files_changed]).to eq(5)
      expect(pr[:additions]).to eq(100)
      expect(pr[:deletions]).to eq(20)
      expect(pr[:review_comments_count]).to eq(2)
    end

    it "normalizes reviews with correct fields" do
      result = described_class.normalize(raw)
      review = result[:contributions].find { |c| c[:type] == "review" }
      expect(review[:id]).to eq("org/repo#42-R_1")
      expect(review[:title]).to start_with("Review:")
      expect(review[:approvals_count]).to eq(1)
    end

    it "filters by date range" do
      raw[:pull_requests] << {
        number: 99, title: "Old PR", body: "",
        html_url: "https://github.com/org/repo/pull/99",
        merged_at: "2024-06-01T00:00:00Z",
        base: { repo: { full_name: "org/repo" } },
        labels: [], changed_files: 1, additions: 1, deletions: 0
      }
      result = described_class.normalize(raw, "2025-01-01", "2025-12-31")
      ids = result[:contributions].map { |c| c[:id] }
      expect(ids).not_to include("org/repo#99")
    end

    it "deduplicates commits associated with PRs" do
      raw[:pull_requests].first[:commits] = [{ sha: "abc1234" }]
      raw[:commits] = [
        { sha: "abc1234", commit: { author: { date: "2025-06-01T00:00:00Z" }, message: "fix" }, repository: { full_name: "org/repo" } },
        { sha: "deadbeef", commit: { author: { date: "2025-06-01T00:00:00Z" }, message: "direct commit" }, repository: { full_name: "org/repo" } }
      ]
      result = described_class.normalize(raw, "2025-01-01", "2025-12-31")
      commit_ids = result[:contributions].select { |c| c[:type] == "issue" }.map { |c| c[:id] }
      expect(commit_ids).not_to include("org/repo#abc1234")
      expect(commit_ids).to include("org/repo#deadbee")
    end
  end
end

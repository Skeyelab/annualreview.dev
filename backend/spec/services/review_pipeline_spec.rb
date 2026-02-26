require "rails_helper"

RSpec.describe ReviewPipeline do
  let(:evidence) do
    {
      timeframe: { start_date: "2025-01-01", end_date: "2025-12-31" },
      contributions: [
        { id: "org/repo#42", type: "pull_request", title: "Fix auth bug",
          url: "https://github.com/org/repo/pull/42", repo: "org/repo",
          merged_at: "2025-06-15T12:00:00Z", body: "Fixes auth flow", summary: "Fixes auth flow" }
      ]
    }
  end

  let(:themes_response) { '{"themes":[{"theme_id":"t1","theme_name":"Reliability","evidence_ids":["org/repo#42"]}]}' }
  let(:bullets_response) { '{"top_10_bullets_overall":[{"text":"Fixed auth"}],"bullets_by_theme":[]}' }
  let(:stories_response) { '{"stories":[{"title":"Auth fix","situation":"broken","task":"fix","actions":["rewrote"],"results":["better"]}]}' }
  let(:self_eval_response) { '{"sections":{"summary":{"text":"Good year"}}}' }

  before do
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(
        { body: { choices: [ { message: { content: themes_response } } ] }.to_json, headers: { "Content-Type" => "application/json" } },
        { body: { choices: [ { message: { content: bullets_response } } ] }.to_json, headers: { "Content-Type" => "application/json" } },
        { body: { choices: [ { message: { content: stories_response } } ] }.to_json, headers: { "Content-Type" => "application/json" } },
        { body: { choices: [ { message: { content: self_eval_response } } ] }.to_json, headers: { "Content-Type" => "application/json" } }
      )
  end

  it "runs 4-step pipeline and returns themes, bullets, stories, self_eval" do
    result = described_class.new(evidence, api_key: "test-key").run
    expect(result).to have_key(:themes)
    expect(result).to have_key(:bullets)
    expect(result).to have_key(:stories)
    expect(result).to have_key(:self_eval)
    expect(result[:themes]["themes"].length).to eq(1)
  end

  it "calls OpenAI 4 times (one per step)" do
    described_class.new(evidence, api_key: "test-key").run
    expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions").times(4)
  end

  it "raises without api_key" do
    original = ENV["OPENAI_API_KEY"]
    ENV.delete("OPENAI_API_KEY")
    expect { described_class.new(evidence).run }.to raise_error(/OPENAI_API_KEY/)
  ensure
    ENV["OPENAI_API_KEY"] = original if original
  end
end

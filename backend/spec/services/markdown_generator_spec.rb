require "rails_helper"

RSpec.describe MarkdownGenerator do
  let(:sample_data) do
    {
      themes: { themes: [
        { theme_id: "t1", theme_name: "Reliability", one_liner: "Made systems reliable",
          why_it_matters: "Uptime matters", confidence: "high",
          anchor_evidence: [ { id: "org/repo#42", title: "Fix auth bug", url: "https://github.com/org/repo/pull/42" } ] }
      ] },
      bullets: {
        top_10_bullets_overall: [
          { text: "Fixed auth bug reducing errors by 50%", evidence: [ { id: "org/repo#42", url: "https://github.com/org/repo/pull/42" } ] }
        ],
        bullets_by_theme: [
          { theme_id: "t1", bullets: [
            { text: "Improved auth flow", evidence: [ { id: "org/repo#42", url: "https://github.com/org/repo/pull/42" } ] }
          ] }
        ]
      },
      stories: { stories: [
        { title: "Auth Overhaul", situation: "Auth was broken", task: "Fix it",
          actions: [ "Rewrote auth middleware" ], results: [ "50% fewer errors" ],
          evidence: [ { id: "org/repo#42", url: "https://github.com/org/repo/pull/42" } ],
          confidence: "high" }
      ] },
      self_eval: { sections: {
        summary: { text: "Strong year focused on reliability.", evidence: [ { id: "org/repo#42", url: "https://github.com/org/repo/pull/42" } ] },
        key_accomplishments: [ { text: "Fixed auth bug", evidence: [ { id: "org/repo#42", url: "https://github.com/org/repo/pull/42" } ] } ],
        how_i_worked: { text: "Collaborated closely with the team." },
        growth: { text: "Grew as an incident responder." },
        next_year_goals: [ { text: "Lead a migration project" } ]
      } }
    }
  end

  it "generates markdown with all sections" do
    md = described_class.generate(sample_data)
    expect(md).to include("# Annual Review Report")
    expect(md).to include("## Themes")
    expect(md).to include("Reliability")
    expect(md).to include("## Impact Bullets")
    expect(md).to include("## STAR Stories")
    expect(md).to include("Auth Overhaul")
    expect(md).to include("## Self-Evaluation")
    expect(md).to include("## Evidence Appendix")
  end

  it "includes timeframe when provided" do
    md = described_class.generate(sample_data, timeframe: { start_date: "2025-01-01", end_date: "2025-12-31" })
    expect(md).to include("2025-01-01")
    expect(md).to include("2025-12-31")
  end

  it "omits timeframe dates when not provided" do
    md = described_class.generate(sample_data)
    expect(md).not_to match(/\d{4}-\d{2}-\d{2}/)
  end

  it "includes Goals section when goals provided" do
    md = described_class.generate(sample_data, goals: "Improve reliability.\nGrow as a tech lead.")
    expect(md).to include("## Goals")
    expect(md).to include("Improve reliability.")
    goals_idx = md.index("## Goals")
    summary_idx = md.index("## Summary")
    expect(goals_idx).to be < summary_idx
  end

  it "omits Goals section when goals not provided or empty" do
    expect(described_class.generate(sample_data)).not_to include("## Goals")
    expect(described_class.generate(sample_data, goals: "")).not_to include("## Goals")
    expect(described_class.generate(sample_data, goals: "   \n  ")).not_to include("## Goals")
  end
end

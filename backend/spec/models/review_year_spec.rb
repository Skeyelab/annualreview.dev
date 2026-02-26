require "rails_helper"

RSpec.describe ReviewYear, type: :model do
  let(:user) { User.create!(github_id: 42, login: "alice") }

  describe "validations" do
    it "requires year" do
      ry = ReviewYear.new(user: user)
      expect(ry).not_to be_valid
      expect(ry.errors[:year]).to include("can't be blank")
    end

    it "enforces unique year per user" do
      ReviewYear.create!(user: user, year: 2025, start_date: "2025-01-01", end_date: "2025-12-31")
      dup = ReviewYear.new(user: user, year: 2025)
      expect(dup).not_to be_valid
      expect(dup.errors[:year]).to include("has already been taken")
    end

    it "allows different users same year" do
      ReviewYear.create!(user: user, year: 2025, start_date: "2025-01-01", end_date: "2025-12-31")
      other = User.create!(github_id: 99, login: "bob")
      ry = ReviewYear.new(user: other, year: 2025, start_date: "2025-01-01", end_date: "2025-12-31")
      expect(ry).to be_valid
    end
  end

  describe "defaults" do
    it "sets start_date and end_date from year" do
      ry = ReviewYear.create!(user: user, year: 2025)
      expect(ry.start_date).to eq("2025-01-01")
      expect(ry.end_date).to eq("2025-12-31")
    end
  end

  describe "JSON columns" do
    it "stores and retrieves evidence as hash" do
      evidence = { "timeframe" => { "start_date" => "2025-01-01", "end_date" => "2025-12-31" }, "contributions" => [] }
      ry = ReviewYear.create!(user: user, year: 2025, evidence: evidence)
      ry.reload
      expect(ry.evidence["timeframe"]["start_date"]).to eq("2025-01-01")
    end

    it "stores and retrieves pipeline_result as hash" do
      result = { "themes" => [], "bullets" => [] }
      ry = ReviewYear.create!(user: user, year: 2025, pipeline_result: result)
      ry.reload
      expect(ry.pipeline_result["themes"]).to eq([])
    end
  end
end

require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    it "requires github_id" do
      user = User.new(login: "alice")
      expect(user).not_to be_valid
      expect(user.errors[:github_id]).to include("can't be blank")
    end

    it "requires login" do
      user = User.new(github_id: 123)
      expect(user).not_to be_valid
      expect(user.errors[:login]).to include("can't be blank")
    end

    it "enforces unique github_id" do
      User.create!(github_id: 123, login: "alice")
      dup = User.new(github_id: 123, login: "bob")
      expect(dup).not_to be_valid
      expect(dup.errors[:github_id]).to include("has already been taken")
    end

    it "is valid with github_id and login" do
      user = User.new(github_id: 456, login: "bob")
      expect(user).to be_valid
    end
  end

  describe ".find_or_create_from_github" do
    it "creates a new user from GitHub data" do
      user = User.find_or_create_from_github(id: 99, login: "newuser")
      expect(user).to be_persisted
      expect(user.github_id).to eq(99)
      expect(user.login).to eq("newuser")
    end

    it "finds existing user and updates login" do
      User.create!(github_id: 99, login: "oldname")
      user = User.find_or_create_from_github(id: 99, login: "newname")
      expect(User.count).to eq(1)
      expect(user.login).to eq("newname")
    end
  end
end

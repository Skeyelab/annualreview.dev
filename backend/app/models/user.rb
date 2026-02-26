class User < ApplicationRecord
  has_many :review_years, dependent: :destroy

  validates :github_id, presence: true, uniqueness: true
  validates :login, presence: true

  def self.find_or_create_from_github(github_data)
    user = find_or_initialize_by(github_id: github_data[:id])
    user.login = github_data[:login]
    user.access_token = github_data[:token] if github_data[:token]
    user.save!
    user
  end
end

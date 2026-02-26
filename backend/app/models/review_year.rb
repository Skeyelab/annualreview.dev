class ReviewYear < ApplicationRecord
  belongs_to :user

  validates :year, presence: true, uniqueness: { scope: :user_id }

  before_validation :set_default_dates

  private

  def set_default_dates
    return unless year
    self.start_date ||= "#{year}-01-01"
    self.end_date ||= "#{year}-12-31"
  end
end

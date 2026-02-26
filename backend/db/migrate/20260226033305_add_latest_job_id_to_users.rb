class AddLatestJobIdToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :latest_job_id, :string
  end
end

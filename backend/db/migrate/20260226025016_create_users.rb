class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.integer :github_id, null: false
      t.string :login, null: false
      t.string :access_token

      t.timestamps
    end
    add_index :users, :github_id, unique: true
  end
end

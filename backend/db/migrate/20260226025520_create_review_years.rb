class CreateReviewYears < ActiveRecord::Migration[8.1]
  def change
    create_table :review_years do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :year, null: false
      t.string :start_date
      t.string :end_date
      t.text :goals
      t.json :evidence
      t.datetime :evidence_updated_at
      t.json :pipeline_result
      t.datetime :pipeline_result_at

      t.timestamps
    end
    add_index :review_years, [ :user_id, :year ], unique: true
  end
end

# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_26_033305) do
  create_table "review_years", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "end_date"
    t.json "evidence"
    t.datetime "evidence_updated_at"
    t.text "goals"
    t.json "pipeline_result"
    t.datetime "pipeline_result_at"
    t.string "start_date"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "year", null: false
    t.index ["user_id", "year"], name: "index_review_years_on_user_id_and_year", unique: true
    t.index ["user_id"], name: "index_review_years_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "access_token"
    t.datetime "created_at", null: false
    t.integer "github_id", null: false
    t.string "latest_job_id"
    t.string "login", null: false
    t.datetime "updated_at", null: false
    t.index ["github_id"], name: "index_users_on_github_id", unique: true
  end

  add_foreign_key "review_years", "users"
end

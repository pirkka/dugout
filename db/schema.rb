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

ActiveRecord::Schema[8.1].define(version: 2026_06_22_183241) do
  create_table "competitions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "format", null: false
    t.integer "league_id", null: false
    t.string "name", null: false
    t.integer "platform", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
  end

  create_table "leagues", force: :cascade do |t|
    t.json "api_data"
    t.string "api_id"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "platform", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["api_id"], name: "index_leagues_on_api_id"
  end

  create_table "teams", force: :cascade do |t|
    t.integer "apothecary"
    t.integer "assistant_coaches"
    t.integer "cash"
    t.integer "cheerleaders"
    t.integer "coach_id"
    t.datetime "created_at", null: false
    t.datetime "inception", null: false
    t.string "logo"
    t.string "name", null: false
    t.integer "popularity"
    t.integer "rerolls"
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.integer "value"
  end
end

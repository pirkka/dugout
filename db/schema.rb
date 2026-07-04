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

ActiveRecord::Schema[8.1].define(version: 2026_07_04_164436) do
  create_table "competition_teams", force: :cascade do |t|
    t.json "api_data"
    t.integer "competition_id", null: false
    t.datetime "created_at", null: false
    t.integer "draws"
    t.integer "losses"
    t.integer "matches"
    t.integer "points"
    t.integer "position"
    t.integer "team_id", null: false
    t.datetime "updated_at", null: false
    t.integer "wins"
    t.index ["competition_id", "team_id"], name: "index_competition_teams_on_competition_id_and_team_id", unique: true
    t.index ["competition_id"], name: "index_competition_teams_on_competition_id"
    t.index ["team_id"], name: "index_competition_teams_on_team_id"
  end

  create_table "competitions", force: :cascade do |t|
    t.json "api_data"
    t.string "api_id"
    t.datetime "created_at", null: false
    t.integer "format", null: false
    t.integer "league_id", null: false
    t.string "name", null: false
    t.integer "platform", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["api_id"], name: "index_competitions_on_api_id"
  end

  create_table "leagues", force: :cascade do |t|
    t.json "api_data"
    t.string "api_id"
    t.datetime "created_at", null: false
    t.integer "game_version", default: 2, null: false
    t.string "name", null: false
    t.integer "platform", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["api_id"], name: "index_leagues_on_api_id"
  end

  create_table "match_teams", force: :cascade do |t|
    t.json "api_data"
    t.integer "conceded"
    t.datetime "created_at", null: false
    t.integer "match_id", null: false
    t.integer "result"
    t.integer "score"
    t.integer "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["match_id", "team_id"], name: "index_match_teams_on_match_id_and_team_id", unique: true
    t.index ["match_id"], name: "index_match_teams_on_match_id"
    t.index ["team_id"], name: "index_match_teams_on_team_id"
  end

  create_table "matches", force: :cascade do |t|
    t.json "api_data"
    t.string "api_id"
    t.integer "competition_id", null: false
    t.datetime "created_at", null: false
    t.datetime "finished"
    t.integer "round"
    t.datetime "started"
    t.datetime "updated_at", null: false
    t.index ["api_id"], name: "index_matches_on_api_id"
    t.index ["competition_id"], name: "index_matches_on_competition_id"
  end

  create_table "teams", force: :cascade do |t|
    t.json "api_data"
    t.string "api_id"
    t.integer "apothecary"
    t.integer "assistant_coaches"
    t.integer "cash"
    t.integer "cheerleaders"
    t.integer "coach_id"
    t.datetime "created_at", null: false
    t.string "logo"
    t.string "name", null: false
    t.integer "popularity"
    t.integer "rerolls"
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.integer "value"
    t.index ["api_id"], name: "index_teams_on_api_id"
  end

  add_foreign_key "competition_teams", "competitions"
  add_foreign_key "competition_teams", "teams"
  add_foreign_key "match_teams", "matches"
  add_foreign_key "match_teams", "teams"
  add_foreign_key "matches", "competitions"
end

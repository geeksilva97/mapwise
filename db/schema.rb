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

ActiveRecord::Schema[8.1].define(version: 2026_02_14_184148) do
  create_table "api_keys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "google_maps_key", null: false
    t.string "label", default: "Default"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_api_keys_on_user_id"
  end

  create_table "map_styles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "style_json", null: false
    t.boolean "system_default", default: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["system_default"], name: "index_map_styles_on_system_default"
    t.index ["user_id"], name: "index_map_styles_on_user_id"
  end

  create_table "maps", force: :cascade do |t|
    t.float "center_lat", default: 0.0
    t.float "center_lng", default: 0.0
    t.datetime "created_at", null: false
    t.text "description"
    t.string "embed_token", null: false
    t.string "google_map_id"
    t.string "map_type", default: "roadmap"
    t.integer "markers_count", default: 0, null: false
    t.boolean "public", default: false
    t.text "style_json"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "zoom", default: 3
    t.index ["embed_token"], name: "index_maps_on_embed_token", unique: true
    t.index ["user_id", "created_at"], name: "index_maps_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_maps_on_user_id"
  end

  create_table "markers", force: :cascade do |t|
    t.string "color", default: "#FF0000"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "icon"
    t.float "lat", null: false
    t.float "lng", null: false
    t.integer "map_id", null: false
    t.integer "position", default: 0
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["map_id", "position"], name: "index_markers_on_map_id_and_position"
    t.index ["map_id"], name: "index_markers_on_map_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "name", default: "", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "api_keys", "users"
  add_foreign_key "map_styles", "users"
  add_foreign_key "maps", "users"
  add_foreign_key "markers", "maps"
  add_foreign_key "sessions", "users"
end

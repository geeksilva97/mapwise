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

ActiveRecord::Schema[8.1].define(version: 2026_03_20_002524) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "api_keys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "google_maps_key", null: false
    t.string "label", default: "Default"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "workspace_id", null: false
    t.index ["user_id"], name: "index_api_keys_on_user_id"
    t.index ["workspace_id"], name: "index_api_keys_on_workspace_id"
  end

  create_table "chat_messages", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.integer "map_id", null: false
    t.string "role", null: false
    t.json "tool_calls"
    t.datetime "updated_at", null: false
    t.index ["map_id", "created_at"], name: "index_chat_messages_on_map_id_and_created_at"
    t.index ["map_id"], name: "index_chat_messages_on_map_id"
  end

  create_table "deviation_alerts", force: :cascade do |t|
    t.boolean "acknowledged", default: false, null: false
    t.datetime "created_at", null: false
    t.float "distance_meters", null: false
    t.string "message"
    t.integer "tracked_vehicle_id", null: false
    t.integer "tracking_point_id"
    t.datetime "updated_at", null: false
    t.index ["tracked_vehicle_id", "acknowledged"], name: "index_deviation_alerts_on_tracked_vehicle_id_and_acknowledged"
    t.index ["tracked_vehicle_id"], name: "index_deviation_alerts_on_tracked_vehicle_id"
    t.index ["tracking_point_id"], name: "index_deviation_alerts_on_tracking_point_id"
  end

  create_table "imports", force: :cascade do |t|
    t.text "column_mapping"
    t.datetime "created_at", null: false
    t.integer "error_count", default: 0
    t.text "error_log"
    t.string "file_name", null: false
    t.integer "map_id", null: false
    t.integer "processed_rows", default: 0
    t.string "status", default: "pending", null: false
    t.integer "success_count", default: 0
    t.integer "total_rows", default: 0
    t.datetime "updated_at", null: false
    t.index ["map_id", "created_at"], name: "index_imports_on_map_id_and_created_at"
    t.index ["map_id"], name: "index_imports_on_map_id"
  end

  create_table "layers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "fill_color", default: "#3B82F6"
    t.float "fill_opacity", default: 0.3
    t.text "geometry_data", null: false
    t.string "layer_type", null: false
    t.integer "map_id", null: false
    t.string "name", null: false
    t.integer "position", default: 0
    t.string "stroke_color", default: "#3B82F6"
    t.integer "stroke_width", default: 2
    t.datetime "updated_at", null: false
    t.boolean "visible", default: true, null: false
    t.index ["map_id", "position"], name: "index_layers_on_map_id_and_position"
    t.index ["map_id"], name: "index_layers_on_map_id"
  end

  create_table "map_styles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "style_json", null: false
    t.boolean "system_default", default: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.integer "workspace_id"
    t.index ["system_default"], name: "index_map_styles_on_system_default"
    t.index ["user_id"], name: "index_map_styles_on_user_id"
    t.index ["workspace_id"], name: "index_map_styles_on_workspace_id"
  end

  create_table "maps", force: :cascade do |t|
    t.float "center_lat", default: 0.0
    t.float "center_lng", default: 0.0
    t.boolean "clustering_enabled", default: false, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "embed_token", null: false
    t.string "google_map_id"
    t.string "map_type", default: "roadmap"
    t.integer "markers_count", default: 0, null: false
    t.boolean "public", default: false
    t.boolean "search_enabled", default: false, null: false
    t.string "search_mode", default: "places", null: false
    t.text "style_json"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "workspace_id", null: false
    t.integer "zoom", default: 3
    t.index ["embed_token"], name: "index_maps_on_embed_token", unique: true
    t.index ["user_id", "created_at"], name: "index_maps_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_maps_on_user_id"
    t.index ["workspace_id"], name: "index_maps_on_workspace_id"
  end

  create_table "marker_groups", force: :cascade do |t|
    t.string "color", default: "#6B7280"
    t.datetime "created_at", null: false
    t.string "icon"
    t.integer "map_id", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.boolean "visible", default: true, null: false
    t.index ["map_id", "position"], name: "index_marker_groups_on_map_id_and_position"
    t.index ["map_id"], name: "index_marker_groups_on_map_id"
  end

  create_table "markers", force: :cascade do |t|
    t.string "color", default: "#FF0000"
    t.datetime "created_at", null: false
    t.text "custom_info_html"
    t.text "description"
    t.string "icon"
    t.float "lat", null: false
    t.float "lng", null: false
    t.integer "map_id", null: false
    t.integer "marker_group_id"
    t.integer "position", default: 0
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["map_id", "position"], name: "index_markers_on_map_id_and_position"
    t.index ["map_id"], name: "index_markers_on_map_id"
    t.index ["marker_group_id"], name: "index_markers_on_marker_group_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "role", default: "editor", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "workspace_id", null: false
    t.index ["user_id", "workspace_id"], name: "index_memberships_on_user_id_and_workspace_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
    t.index ["workspace_id"], name: "index_memberships_on_workspace_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "tracked_vehicles", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "color", default: "#3B82F6"
    t.datetime "created_at", null: false
    t.float "deviation_threshold_meters"
    t.string "icon"
    t.integer "map_id", null: false
    t.string "name", null: false
    t.text "planned_path"
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "webhook_token", null: false
    t.index ["map_id", "position"], name: "index_tracked_vehicles_on_map_id_and_position"
    t.index ["map_id"], name: "index_tracked_vehicles_on_map_id"
    t.index ["webhook_token"], name: "index_tracked_vehicles_on_webhook_token", unique: true
  end

  create_table "tracking_points", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.float "heading"
    t.float "lat", null: false
    t.float "lng", null: false
    t.datetime "recorded_at", null: false
    t.float "speed"
    t.integer "tracked_vehicle_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tracked_vehicle_id", "recorded_at"], name: "index_tracking_points_on_tracked_vehicle_id_and_recorded_at"
    t.index ["tracked_vehicle_id"], name: "index_tracking_points_on_tracked_vehicle_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.boolean "email_verified", default: false, null: false
    t.datetime "email_verified_at"
    t.string "name", default: "", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "workspaces", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.boolean "personal", default: false, null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_keys", "users"
  add_foreign_key "api_keys", "workspaces"
  add_foreign_key "chat_messages", "maps"
  add_foreign_key "deviation_alerts", "tracked_vehicles"
  add_foreign_key "deviation_alerts", "tracking_points"
  add_foreign_key "imports", "maps"
  add_foreign_key "layers", "maps"
  add_foreign_key "map_styles", "users"
  add_foreign_key "map_styles", "workspaces"
  add_foreign_key "maps", "users"
  add_foreign_key "maps", "workspaces"
  add_foreign_key "marker_groups", "maps"
  add_foreign_key "markers", "maps"
  add_foreign_key "markers", "marker_groups"
  add_foreign_key "memberships", "users"
  add_foreign_key "memberships", "workspaces"
  add_foreign_key "sessions", "users"
  add_foreign_key "tracked_vehicles", "maps"
  add_foreign_key "tracking_points", "tracked_vehicles"
end

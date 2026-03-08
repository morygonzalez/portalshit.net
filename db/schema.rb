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

ActiveRecord::Schema.define(version: 2026_03_08_000002) do

  create_table "activities", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "title", null: false
    t.string "activity_type"
    t.datetime "started_at"
    t.integer "duration_seconds"
    t.decimal "total_distance_meters", precision: 10, scale: 2
    t.decimal "total_ascent_meters", precision: 8, scale: 2
    t.integer "avg_heart_rate"
    t.integer "max_heart_rate"
    t.decimal "avg_speed", precision: 6, scale: 2
    t.integer "avg_cadence"
    t.integer "avg_power"
    t.string "original_filename"
    t.string "file_url"
    t.string "file_format"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "device_manufacturer"
    t.integer "device_product_id"
    t.string "device_display_name"
    t.string "file_hash"
    t.index ["activity_type"], name: "index_activities_on_activity_type"
    t.index ["file_hash"], name: "index_activities_on_file_hash", unique: true
    t.index ["started_at"], name: "index_activities_on_started_at"
    t.index ["user_id"], name: "fk_rails_7e11bb717f"
  end

  create_table "activity_data_points", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "activity_id", null: false
    t.integer "elapsed_seconds"
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.decimal "altitude_meters", precision: 7, scale: 2
    t.integer "heart_rate"
    t.decimal "speed", precision: 6, scale: 2
    t.integer "cadence"
    t.integer "power"
    t.decimal "distance_meters", precision: 10, scale: 2
    t.index ["activity_id", "elapsed_seconds"], name: "index_activity_data_points_on_activity_id_and_elapsed_seconds"
  end

  create_table "categories", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "slug"
    t.string "title", collation: "utf8mb4_general_ci"
    t.text "description", collation: "utf8mb4_general_ci"
    t.text "type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "parent_id"
    t.index ["slug"], name: "unique_categories_slug", unique: true
    t.index ["title"], name: "unique_categories_title", unique: true
  end

  create_table "comments", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "entry_id"
    t.integer "status"
    t.string "name", limit: 50
    t.string "homepage"
    t.text "body"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "email", limit: 40, collation: "utf8mb3_general_ci"
    t.index ["status", "entry_id"], name: "index_comments_status_entry_id"
    t.index ["status"], name: "index_comments_status"
  end

  create_table "entries", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "user_id"
    t.integer "category_id"
    t.string "slug", collation: "utf8mb3_general_ci"
    t.string "title"
    t.text "body"
    t.string "type", limit: 50, default: "", null: false, collation: "utf8mb3_general_ci"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "frozen_tag_list", collation: "utf8mb3_general_ci"
    t.string "markup", collation: "utf8mb3_general_ci"
    t.text "summary"
    t.datetime "publish_at"
    t.index ["created_at"], name: "index_entry_created_at"
    t.index ["publish_at"], name: "index_entries_on_publish_at"
    t.index ["slug"], name: "index_entry_slug"
    t.index ["title", "body"], name: "index_entry_fulltext", type: :fulltext
    t.index ["type"], name: "index_entry_type"
  end

  create_table "entry_term_frequencies", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "entry_id", null: false
    t.string "term", null: false
    t.integer "term_count", default: 0, null: false
    t.datetime "entry_updated_at", null: false
    t.index ["entry_id", "term"], name: "index_entry_term_frequencies_on_entry_id_and_term", unique: true
    t.index ["entry_id"], name: "index_entry_term_frequencies_on_entry_id"
  end

  create_table "field_names", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["name"], name: "index_field_names_name"
  end

  create_table "fields", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "field_name_id"
    t.integer "entry_id"
    t.text "value"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "options", primary_key: "name", id: :string, charset: "utf8mb3", force: :cascade do |t|
    t.text "value"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["name"], name: "index_name"
  end

  create_table "similarities", primary_key: ["entry_id", "similar_entry_id"], charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "entry_id", null: false
    t.integer "similar_entry_id", null: false
    t.float "score"
    t.index ["entry_id", "similar_entry_id"], name: "index_similarity_entry_id_similar_entry_id", unique: true
  end

  create_table "sites", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "title", collation: "utf8mb4_general_ci"
    t.text "description"
    t.text "dashboard"
    t.string "theme", limit: 64
    t.string "meta_description", collation: "utf8mb4_general_ci"
    t.string "meta_keywords", collation: "utf8mb4_general_ci"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "mobile_theme", limit: 64
    t.string "default_sort"
    t.string "default_order"
    t.integer "per_page"
    t.string "default_markup"
  end

  create_table "snippets", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "name", collation: "utf8mb4_general_ci"
    t.text "body", collation: "utf8mb4_general_ci"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "taggings", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "taggable_id", null: false
    t.text "taggable_type", null: false
    t.integer "tag_id", null: false
    t.index ["tag_id"], name: "index_taggings_tag"
    t.index ["taggable_id"], name: "index_taggings_taggable_id"
  end

  create_table "tags", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "name", limit: 50, default: "", null: false, collation: "utf8mb4_general_ci"
    t.index ["name"], name: "unique_tags_name", unique: true
  end

  create_table "users", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "name", limit: 40, collation: "utf8mb4_general_ci"
    t.string "email", limit: 40
    t.string "hashed_password", limit: 50
    t.string "salt", limit: 50
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "permission_level", default: 1
    t.string "password_digest", limit: 60
    t.index ["email"], name: "unique_users_email", unique: true
    t.index ["name"], name: "unique_users_name", unique: true
  end

  add_foreign_key "activities", "users"
  add_foreign_key "activity_data_points", "activities"
end

# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_05_05_000000) do

  create_table "categories", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "slug"
    t.string "title", collation: "utf8mb4_general_ci"
    t.text "description", collation: "utf8mb4_general_ci"
    t.text "type", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "parent_id"
    t.index ["slug"], name: "unique_categories_slug", unique: true
    t.index ["title"], name: "unique_categories_title", unique: true
  end

  create_table "comments", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4", force: :cascade do |t|
    t.integer "entry_id"
    t.integer "status"
    t.string "name", limit: 50
    t.string "homepage", limit: 50, collation: "utf8_general_ci"
    t.text "body"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "email", limit: 40, collation: "utf8_general_ci"
    t.index ["status", "entry_id"], name: "index_comments_status_entry_id"
    t.index ["status"], name: "index_comments_status"
  end

  create_table "entries", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4", force: :cascade do |t|
    t.integer "user_id"
    t.integer "category_id"
    t.string "slug", collation: "utf8_general_ci"
    t.string "title"
    t.text "body"
    t.string "type", limit: 50, default: "", null: false, collation: "utf8_general_ci"
    t.boolean "draft", default: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "frozen_tag_list", collation: "utf8_general_ci"
    t.string "markup", collation: "utf8_general_ci"
    t.index ["created_at"], name: "index_entry_created_at"
    t.index ["draft"], name: "index_entry_draft"
    t.index ["slug"], name: "index_entry_slug"
    t.index ["type"], name: "index_entry_type"
  end

  create_table "field_names", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["name"], name: "index_field_names_name"
  end

  create_table "fields", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "field_name_id"
    t.integer "entry_id"
    t.text "value"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "options", primary_key: "name", id: :string, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.text "value"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["name"], name: "index_name"
  end

  create_table "similarities", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "entry_id"
    t.integer "similar_entry_id"
    t.integer "score"
    t.index ["entry_id", "similar_entry_id"], name: "index_similarities_on_entry_id_and_similar_entry_id", unique: true
  end

  create_table "sites", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "title", collation: "utf8mb4_general_ci"
    t.string "description", collation: "utf8mb4_general_ci"
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

  create_table "snippets", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", collation: "utf8mb4_general_ci"
    t.text "body", collation: "utf8mb4_general_ci"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "taggings", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "taggable_id", null: false
    t.text "taggable_type", null: false
    t.string "tag_context", limit: 50, null: false
    t.integer "tag_id", null: false
    t.index ["tag_id"], name: "index_taggings_tag"
    t.index ["taggable_id"], name: "index_taggings_taggable_id"
  end

  create_table "tags", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", limit: 50, default: "", null: false, collation: "utf8mb4_general_ci"
    t.index ["name"], name: "unique_tags_name", unique: true
  end

  create_table "users", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", limit: 40, collation: "utf8mb4_general_ci"
    t.string "email", limit: 40
    t.string "hashed_password", limit: 50
    t.string "salt", limit: 50
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "permission_level", default: 1
    t.index ["email"], name: "unique_users_email", unique: true
    t.index ["name"], name: "unique_users_name", unique: true
  end

end

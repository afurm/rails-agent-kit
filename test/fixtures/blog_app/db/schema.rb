# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.

ActiveRecord::Schema[8.0].define(version: 2026_10_01_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "comments", force: :cascade do |t|
    t.bigint "post_id", null: false
    t.bigint "user_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id"], name: "index_comments_on_post_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "posts", force: :cascade do |t|
    t.string "title", limit: 200, null: false
    t.text "body"
    t.integer "status", default: 0, null: false # draft, published
    t.decimal "rating", precision: 3, scale: 1
    t.string "tags", default: [], array: true
    t.bigint "user_id", null: false
    t.datetime "published_at"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "published_at"], name: "index_posts_on_user_id_and_published_at"
    t.index ["title"], name: "index_posts_on_title", unique: true, where: "(status = 1)"
  end

  create_table "posts_tags", id: false, force: :cascade do |t|
    t.bigint "post_id", null: false
    t.bigint "tag_id", null: false
  end

  create_table "users", id: :uuid, comment: "People who can log in", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "display_name", comment: "Shown publicly, may contain # signs"
    t.boolean "admin", default: false, null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "comments", "posts"
  add_foreign_key "comments", "users", on_delete: :cascade
  add_foreign_key "posts", "users", column: "user_id"
end

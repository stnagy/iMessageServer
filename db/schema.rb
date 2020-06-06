# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_06_05_221707) do

  create_table "chat_contacts", force: :cascade do |t|
    t.integer "chat_id"
    t.integer "contact_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["chat_id"], name: "index_chat_contacts_on_chat_id"
    t.index ["contact_id"], name: "index_chat_contacts_on_contact_id"
  end

  create_table "chats", force: :cascade do |t|
    t.text "guid"
    t.text "nickname"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "contact_messages", force: :cascade do |t|
    t.integer "contact_id"
    t.integer "message_id"
    t.boolean "is_sender"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["contact_id"], name: "index_contact_messages_on_contact_id"
    t.index ["message_id"], name: "index_contact_messages_on_message_id"
  end

  create_table "contacts", force: :cascade do |t|
    t.text "contact_name"
    t.text "contact_number"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "nickname"
  end

  create_table "messages", force: :cascade do |t|
    t.text "message_text"
    t.boolean "has_attachment"
    t.text "attachment_filetype"
    t.boolean "needs_sms_forwarding", default: false
    t.text "twilio_message_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "rowid"
    t.integer "chat_id"
    t.index ["chat_id"], name: "index_messages_on_chat_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "preferences"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "contact_messages", "contacts"
  add_foreign_key "contact_messages", "messages"
  add_foreign_key "messages", "chats"
end

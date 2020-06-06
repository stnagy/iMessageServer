class CreateChats < ActiveRecord::Migration[6.0]
  def change
    create_table :chats do |t|
      t.text :guid
      t.text :nickname
      t.timestamps
    end

    add_reference :messages, :chat, index: true
    add_foreign_key :messages, :chats

    create_table :chat_contacts do |t|
      t.references :chat
      t.references :contact
      t.timestamps
    end

    add_column :contacts, :nickname, :text
  end
end

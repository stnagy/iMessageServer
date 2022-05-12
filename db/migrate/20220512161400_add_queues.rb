class AddQueues < ActiveRecord::Migration[7.0]
  def change

    create_table :to_user_queues do |t|
      t.references :message
      t.boolean :sent, default: false
      t.datetime :sent_time
    end

    create_table :to_recipient_queues do |t|
      t.references :message
      t.boolean :sent, default: false
      t.datetime :sent_time
    end

    remove_column :messages, :needs_sms_forwarding
    remove_column :messages, :needs_imessage_forwarding

  end
end

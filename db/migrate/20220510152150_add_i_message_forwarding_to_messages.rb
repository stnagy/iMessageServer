class AddIMessageForwardingToMessages < ActiveRecord::Migration[7.0]
  def change

    add_column :messages, :needs_imessage_forwarding, :boolean, default: false

  end
end

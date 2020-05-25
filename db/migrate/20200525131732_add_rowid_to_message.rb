class AddRowidToMessage < ActiveRecord::Migration[6.0]
  def change
    add_column :messages, :rowid, :integer
  end
end

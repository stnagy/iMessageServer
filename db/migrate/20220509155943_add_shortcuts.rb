class AddShortcuts < ActiveRecord::Migration[7.0]
  def change

    create_table :shortcuts do |t|
      t.references :user
      t.text :name
      t.integer :number
      t.timestamps

    end

  end
end

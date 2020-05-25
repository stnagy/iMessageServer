class CreateContacts < ActiveRecord::Migration[6.0]
  def change
    create_table :contacts do |t|
      t.text        :contact_name
      t.text        :contact_number

      t.timestamps
    end
  end
end

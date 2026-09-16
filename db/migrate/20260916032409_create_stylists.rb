class CreateStylists < ActiveRecord::Migration[8.1]
  def change
    create_table :stylists do |t|
      t.string :name, null: false
      t.string :specialty, null: false
      t.text :bio

      t.timestamps
    end
  end
end

class CreateServices < ActiveRecord::Migration[8.1]
  def change
    create_table :services do |t|
      t.string :name, null: false
      t.text :description
      t.integer :duration_minutes, null: false
      t.decimal :price, precision: 8, scale: 2, null: false
      t.references :category, null: false, foreign_key: true

      t.timestamps
    end
  end
end

class CreateAppointments < ActiveRecord::Migration[8.1]
  def change
    create_table :appointments do |t|
      t.references :client, null: false, foreign_key: true
      t.references :stylist, null: false, foreign_key: true
      t.datetime :scheduled_at, null: false
      t.string :status, null: false, default: "pending"
      t.text :notes

      t.timestamps
    end
  end
end

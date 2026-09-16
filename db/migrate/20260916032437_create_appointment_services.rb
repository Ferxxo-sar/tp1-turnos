class CreateAppointmentServices < ActiveRecord::Migration[8.1]
  def change
    create_table :appointment_services do |t|
      t.references :appointment, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.decimal :price_at_booking, precision: 8, scale: 2, null: false

      t.timestamps
    end
    add_index :appointment_services, %i[appointment_id service_id], unique: true, name: "index_appointment_services_on_appointment_and_service"
  end
end

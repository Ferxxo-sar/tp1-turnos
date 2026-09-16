class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :phone
      t.string :api_token

      t.timestamps
    end
    add_index :clients, :email, unique: true
    add_index :clients, :api_token, unique: true
  end
end

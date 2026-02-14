class CreateApiKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :api_keys do |t|
      t.references :user, null: false, foreign_key: true
      t.text :google_maps_key, null: false
      t.string :label, default: "Default"

      t.timestamps
    end
  end
end

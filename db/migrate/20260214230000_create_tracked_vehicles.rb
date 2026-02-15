class CreateTrackedVehicles < ActiveRecord::Migration[8.1]
  def change
    create_table :tracked_vehicles do |t|
      t.references :map, null: false, foreign_key: true
      t.string :name, null: false
      t.string :webhook_token, null: false
      t.string :color, default: "#3B82F6"
      t.string :icon
      t.text :planned_path
      t.float :deviation_threshold_meters
      t.boolean :active, default: true, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :tracked_vehicles, :webhook_token, unique: true
    add_index :tracked_vehicles, [:map_id, :position]
  end
end

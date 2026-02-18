class CreateDeviationAlerts < ActiveRecord::Migration[8.1]
  def change
    create_table :deviation_alerts do |t|
      t.references :tracked_vehicle, null: false, foreign_key: true
      t.references :tracking_point, foreign_key: true
      t.float :distance_meters, null: false
      t.string :message
      t.boolean :acknowledged, default: false, null: false

      t.timestamps
    end

    add_index :deviation_alerts, [ :tracked_vehicle_id, :acknowledged ]
  end
end

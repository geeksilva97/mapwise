class CreateTrackingPoints < ActiveRecord::Migration[8.1]
  def change
    create_table :tracking_points do |t|
      t.references :tracked_vehicle, null: false, foreign_key: true
      t.float :lat, null: false
      t.float :lng, null: false
      t.float :speed
      t.float :heading
      t.datetime :recorded_at, null: false

      t.timestamps
    end

    add_index :tracking_points, [:tracked_vehicle_id, :recorded_at]
  end
end

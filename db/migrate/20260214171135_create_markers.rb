class CreateMarkers < ActiveRecord::Migration[8.1]
  def change
    create_table :markers do |t|
      t.references :map, null: false, foreign_key: true
      t.float :lat, null: false
      t.float :lng, null: false
      t.string :title
      t.text :description
      t.string :color, default: "#FF0000"
      t.string :icon
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :markers, [ :map_id, :position ]
  end
end

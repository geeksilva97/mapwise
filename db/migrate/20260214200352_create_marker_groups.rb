class CreateMarkerGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :marker_groups do |t|
      t.references :map, null: false, foreign_key: true
      t.string :name, null: false
      t.string :color, default: "#6B7280"
      t.string :icon
      t.boolean :visible, default: true, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end
    add_index :marker_groups, [ :map_id, :position ]
  end
end

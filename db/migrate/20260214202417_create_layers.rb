class CreateLayers < ActiveRecord::Migration[8.1]
  def change
    create_table :layers do |t|
      t.references :map, null: false, foreign_key: true
      t.string :name, null: false
      t.string :layer_type, null: false
      t.text :geometry_data, null: false
      t.string :stroke_color, default: "#3B82F6"
      t.integer :stroke_width, default: 2
      t.string :fill_color, default: "#3B82F6"
      t.float :fill_opacity, default: 0.3
      t.boolean :visible, default: true, null: false
      t.integer :position, default: 0
      t.timestamps
    end
    add_index :layers, [:map_id, :position]
  end
end

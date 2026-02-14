class CreateMaps < ActiveRecord::Migration[8.1]
  def change
    create_table :maps do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.float :center_lat, default: 0.0
      t.float :center_lng, default: 0.0
      t.integer :zoom, default: 3
      t.string :map_type, default: "roadmap"
      t.string :embed_token, null: false
      t.boolean :public, default: false
      t.text :style_json
      t.string :google_map_id

      t.timestamps
    end

    add_index :maps, :embed_token, unique: true
    add_index :maps, [ :user_id, :created_at ]
  end
end

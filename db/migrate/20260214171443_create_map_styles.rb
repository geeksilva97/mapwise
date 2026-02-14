class CreateMapStyles < ActiveRecord::Migration[8.1]
  def change
    create_table :map_styles do |t|
      t.references :user, foreign_key: true
      t.string :name, null: false
      t.text :style_json, null: false
      t.boolean :system_default, default: false

      t.timestamps
    end

    add_index :map_styles, :system_default
  end
end

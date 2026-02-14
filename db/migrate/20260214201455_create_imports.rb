class CreateImports < ActiveRecord::Migration[8.1]
  def change
    create_table :imports do |t|
      t.references :map, null: false, foreign_key: true
      t.string :status, default: "pending", null: false
      t.string :file_name, null: false
      t.integer :total_rows, default: 0
      t.integer :processed_rows, default: 0
      t.integer :success_count, default: 0
      t.integer :error_count, default: 0
      t.text :error_log
      t.text :column_mapping
      t.timestamps
    end
    add_index :imports, [:map_id, :created_at]
  end
end

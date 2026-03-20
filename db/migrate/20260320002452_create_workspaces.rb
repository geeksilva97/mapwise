class CreateWorkspaces < ActiveRecord::Migration[8.1]
  def change
    create_table :workspaces do |t|
      t.string :name, null: false
      t.boolean :personal, default: false, null: false

      t.timestamps
    end
  end
end

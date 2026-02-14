class AddSearchFieldsToMaps < ActiveRecord::Migration[8.1]
  def change
    add_column :maps, :search_enabled, :boolean, default: false, null: false
    add_column :maps, :search_mode, :string, default: "places", null: false
  end
end

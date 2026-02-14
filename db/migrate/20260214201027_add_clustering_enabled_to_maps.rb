class AddClusteringEnabledToMaps < ActiveRecord::Migration[8.1]
  def change
    add_column :maps, :clustering_enabled, :boolean, default: false, null: false
  end
end

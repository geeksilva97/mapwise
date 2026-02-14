class AddMarkersCountToMaps < ActiveRecord::Migration[8.1]
  def up
    add_column :maps, :markers_count, :integer, default: 0, null: false

    Map.reset_column_information
    Map.find_each do |map|
      Map.update_counters(map.id, markers_count: map.markers.count)
    end
  end

  def down
    remove_column :maps, :markers_count
  end
end

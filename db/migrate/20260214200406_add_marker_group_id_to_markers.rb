class AddMarkerGroupIdToMarkers < ActiveRecord::Migration[8.1]
  def change
    add_reference :markers, :marker_group, null: true, foreign_key: true
  end
end

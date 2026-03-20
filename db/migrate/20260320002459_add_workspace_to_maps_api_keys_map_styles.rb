class AddWorkspaceToMapsApiKeysMapStyles < ActiveRecord::Migration[8.1]
  def change
    add_reference :maps, :workspace, foreign_key: true
    add_reference :api_keys, :workspace, foreign_key: true
    add_reference :map_styles, :workspace, foreign_key: true
  end
end

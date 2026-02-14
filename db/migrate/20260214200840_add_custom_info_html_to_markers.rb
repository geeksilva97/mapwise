class AddCustomInfoHtmlToMarkers < ActiveRecord::Migration[8.1]
  def change
    add_column :markers, :custom_info_html, :text
  end
end

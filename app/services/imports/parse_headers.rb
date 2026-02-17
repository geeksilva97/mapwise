class Imports::ParseHeaders
  def self.call(import)
    import.file.blob.open do |tempfile|
      ext = File.extname(import.file_name).downcase
      case ext
      when ".csv"
        CSV.read(tempfile.path, headers: true).headers
      when ".xlsx", ".xls"
        spreadsheet = Roo::Spreadsheet.open(tempfile.path, extension: ext.delete("."))
        spreadsheet.row(1)
      else
        []
      end
    end
  rescue => e
    Rails.logger.error "Failed to parse headers: #{e.message}"
    []
  end
end

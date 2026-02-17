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
  rescue StandardError => e
    Rails.error.report(e, handled: true, context: { import_id: import.id, file_name: import.file_name }, source: "imports/parse_headers")
    []
  end
end

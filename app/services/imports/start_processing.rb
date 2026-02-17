class Imports::StartProcessing
  def self.call(import, column_mapping)
    import.update!(column_mapping: column_mapping, status: "processing")
    ::CsvImportJob.perform_later(import.id)
    import
  end
end

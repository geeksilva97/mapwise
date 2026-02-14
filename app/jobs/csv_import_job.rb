class CsvImportJob < ApplicationJob
  queue_as :default

  def perform(import_id)
    import = Import.find(import_id)
    ImportService.new(import).process
  rescue => e
    import&.update(status: "failed", error_log: [{ row: 0, message: e.message }])
    Rails.logger.error "CsvImportJob failed: #{e.message}"
  end
end

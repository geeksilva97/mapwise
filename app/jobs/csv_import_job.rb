class CsvImportJob < ApplicationJob
  queue_as :default

  def perform(import_id)
    import = Import.find(import_id)
    ImportService.new(import).process
  rescue StandardError => e
    import&.update(status: "failed", error_log: [ { row: 0, message: e.message } ])
    Rails.error.report(e, handled: true, context: { import_id: import_id }, source: "csv_import_job")
  end
end

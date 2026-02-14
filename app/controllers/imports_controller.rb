class ImportsController < ApplicationController
  before_action :set_map
  before_action :set_import, only: %i[ show update ]

  def create
    unless params[:file].present?
      return respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("import_area", html: helpers.tag.div(id: "import_area") { helpers.tag.p("Please select a file.", class: "text-sm text-red-600") }) }
        format.json { render json: { error: "No file uploaded" }, status: :unprocessable_entity }
        format.html { redirect_to edit_map_path(@map), alert: "Please select a file." }
      end
    end

    file = params[:file]
    @import = @map.imports.build(
      file_name: file.original_filename,
      status: "mapping"
    )
    @import.file.attach(file)

    if @import.save
      headers = parse_headers(@import)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("import_area",
            partial: "imports/column_mapping",
            locals: { import: @import, map: @map, headers: headers })
        end
        format.json { render json: { id: @import.id, headers: headers } }
        format.html { redirect_to edit_map_path(@map), notice: "File uploaded. Map your columns." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("import_area", partial: "imports/upload", locals: { map: @map, error: "Failed to save import." }) }
        format.json { render json: @import.errors, status: :unprocessable_entity }
        format.html { redirect_to edit_map_path(@map), alert: "Failed to upload file." }
      end
    end
  end

  def show
    respond_to do |format|
      format.turbo_stream do
        if @import.completed? || @import.failed?
          render turbo_stream: turbo_stream.replace("import_area",
            partial: "imports/completed",
            locals: { import: @import, map: @map })
        else
          render turbo_stream: turbo_stream.replace("import_area",
            partial: "imports/progress",
            locals: { import: @import })
        end
      end
      format.json do
        render json: {
          id: @import.id,
          status: @import.status,
          total_rows: @import.total_rows,
          processed_rows: @import.processed_rows,
          success_count: @import.success_count,
          error_count: @import.error_count,
          progress: @import.progress_percentage
        }
      end
    end
  end

  def update
    mapping = params.require(:column_mapping).permit(:lat, :lng, :address, :title, :description, :color, :group)
    @import.update!(column_mapping: mapping.to_h, status: "processing")

    CsvImportJob.perform_later(@import.id)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("import_area",
          partial: "imports/progress",
          locals: { import: @import })
      end
      format.json { render json: { id: @import.id, status: "processing" } }
    end
  end

  private

  def set_map
    @map = Current.user.maps.find(params[:map_id])
  end

  def set_import
    @import = @map.imports.find(params[:id])
  end

  def parse_headers(import)
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

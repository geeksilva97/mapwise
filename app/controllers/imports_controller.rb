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

    result = Imports::CreateFromUpload.call(@map, params[:file])

    if result[:error]
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("import_area", partial: "imports/upload", locals: { map: @map, error: "Failed to save import." }) }
        format.json { render json: result[:error], status: :unprocessable_entity }
        format.html { redirect_to edit_map_path(@map), alert: "Failed to upload file." }
      end
    else
      @import = result[:import]
      headers = result[:headers]
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("import_area",
            partial: "imports/column_mapping",
            locals: { import: @import, map: @map, headers: headers })
        end
        format.json { render json: { id: @import.id, headers: headers } }
        format.html { redirect_to edit_map_path(@map), notice: "File uploaded. Map your columns." }
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
    Imports::StartProcessing.call(@import, mapping.to_h)

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
    @map = Maps::Find.call(Current.user, params[:map_id])
  end

  def set_import
    @import = @map.imports.find(params[:id])
  end
end

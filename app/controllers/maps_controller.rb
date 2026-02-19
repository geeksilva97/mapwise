class MapsController < ApplicationController
  layout "fullscreen", only: %i[ show edit tracking ]
  before_action :set_map, only: %i[ show edit update destroy tracking ]

  def new
    @map = Maps::Build.call(Current.user)
  end

  def create
    @map = Maps::Create.call(Current.user, map_params)

    if @map.persisted?
      redirect_to edit_map_path(@map)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
  end

  def tracking
  end

  def update
    if Maps::Update.call(@map, map_params)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("settings_feedback") {
              helpers.tag.p("Settings saved.", class: "text-sm text-green-600 font-medium")
            },
            turbo_stream.update("map_title", @map.title)
          ]
        end
        format.html { redirect_to edit_map_path(@map), notice: "Map updated." }
        format.json { head :ok }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("map_settings_form",
            partial: "form", locals: { map: @map })
        end
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @map.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    Maps::Destroy.call(@map)
    redirect_to root_path, notice: "Map deleted.", status: :see_other
  end

  private

  def set_map
    @map = Maps::Find.call(Current.user, params[:id])
  end

  def map_params
    params.require(:map).permit(:title, :description, :center_lat, :center_lng,
                                :zoom, :map_type, :public, :style_json, :google_map_id,
                                :clustering_enabled, :search_enabled, :search_mode)
  end
end

class LayersController < ApplicationController
  before_action :set_map
  before_action :set_layer, only: %i[ update destroy toggle_visibility ]

  def create
    @layer = Layers::Create.call(@map, layer_params)

    if @layer.persisted?
      respond_to do |format|
        format.turbo_stream
        format.json { render json: @layer }
      end
    else
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.json { render json: @layer.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    if Layers::Update.call(@layer, layer_params)
      respond_to do |format|
        format.turbo_stream
        format.json { render json: @layer }
      end
    else
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.json { render json: @layer.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    Layers::Destroy.call(@layer)
    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  def toggle_visibility
    Layers::ToggleVisibility.call(@layer)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("layer_#{@layer.id}", partial: "layers/layer_item", locals: { layer: @layer }) }
      format.json { render json: @layer }
    end
  end

  private

  def set_map
    @map = Maps::Find.call(Current.workspace, params[:map_id])
  end

  def set_layer
    @layer = Layers::Find.call(@map, params[:id])
  end

  def layer_params
    params.require(:layer).permit(:name, :layer_type, :geometry_data, :stroke_color, :stroke_width, :fill_color, :fill_opacity, :visible)
  end
end

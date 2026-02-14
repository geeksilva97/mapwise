class LayersController < ApplicationController
  before_action :set_map
  before_action :set_layer, only: %i[ update destroy toggle_visibility ]

  def create
    @layer = @map.layers.build(layer_params)

    if @layer.save
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
    if @layer.update(layer_params)
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
    @layer.destroy
    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  def toggle_visibility
    @layer.update!(visible: !@layer.visible)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("layer_#{@layer.id}", partial: "layers/layer_item", locals: { layer: @layer }) }
      format.json { render json: @layer }
    end
  end

  private

  def set_map
    @map = Current.user.maps.find(params[:map_id])
  end

  def set_layer
    @layer = @map.layers.find(params[:id])
  end

  def layer_params
    params.require(:layer).permit(:name, :layer_type, :geometry_data, :stroke_color, :stroke_width, :fill_color, :fill_opacity, :visible)
  end
end

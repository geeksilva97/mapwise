class MapwiseError < StandardError
  attr_reader :context

  def initialize(message = nil, context: {})
    @context = context
    super(message)
  end
end

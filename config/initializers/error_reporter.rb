class MapwiseErrorReporter
  def report(error, handled:, severity:, context: {}, source: nil)
    label = handled ? "handled" : "unhandled"
    source_tag = source ? " [#{source}]" : ""

    merged_context = error.respond_to?(:context) ? error.context.merge(context) : context
    context_str = merged_context.any? ? " | context: #{merged_context.inspect}" : ""

    app_tag = defined?(Branding) ? Branding.app_name : "MapWise"
    line = "[#{app_tag}] #{severity.upcase} (#{label})#{source_tag} #{error.class}: #{error.message}#{context_str}"

    case severity.to_sym
    when :error   then Rails.logger.error(line)
    when :warning then Rails.logger.warn(line)
    else               Rails.logger.info(line)
    end

    return if handled

    backtrace = error.backtrace&.first(10)&.join("\n  ")
    Rails.logger.error("  #{backtrace}") if backtrace
  end
end

Rails.error.subscribe(MapwiseErrorReporter.new)

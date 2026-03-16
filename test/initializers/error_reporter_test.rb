require "test_helper"

class ErrorReporterTest < ActiveSupport::TestCase
  test "MapwiseErrorReporter is subscribed to Rails.error" do
    subscribers = Rails.error.instance_variable_get(:@subscribers)
    assert subscribers.any? { |s| s.is_a?(MapwiseErrorReporter) },
      "Expected MapwiseErrorReporter to be subscribed to Rails.error"
  end

  test "report handles MapwiseError with context" do
    reporter = MapwiseErrorReporter.new
    error = ImportError.new("bad file", context: { import_id: 42 })

    output = capture_log do
      reporter.report(error, handled: true, severity: :error, context: { extra: "info" }, source: "test")
    end

    assert_includes output, "[#{Branding.app_name}]"
    assert_includes output, "ERROR"
    assert_includes output, "(handled)"
    assert_includes output, "[test]"
    assert_includes output, "ImportError"
    assert_includes output, "bad file"
    assert_includes output, "import_id"
    assert_includes output, "extra"
  end

  test "report handles plain StandardError" do
    reporter = MapwiseErrorReporter.new
    error = StandardError.new("boom")

    output = capture_log do
      reporter.report(error, handled: true, severity: :warning, context: {}, source: "manual")
    end

    assert_includes output, "WARN"
    assert_includes output, "StandardError"
    assert_includes output, "boom"
  end

  test "report includes backtrace for unhandled errors" do
    reporter = MapwiseErrorReporter.new
    error = StandardError.new("crash")
    error.set_backtrace([ "app/jobs/foo.rb:10:in `perform'", "app/jobs/bar.rb:20:in `call'" ])

    output = capture_log do
      reporter.report(error, handled: false, severity: :error, context: {}, source: nil)
    end

    assert_includes output, "app/jobs/foo.rb:10"
    assert_includes output, "(unhandled)"
  end

  test "report omits backtrace for handled errors" do
    reporter = MapwiseErrorReporter.new
    error = StandardError.new("minor")
    error.set_backtrace([ "app/jobs/foo.rb:10:in `perform'" ])

    output = capture_log do
      reporter.report(error, handled: true, severity: :error, context: {}, source: nil)
    end

    # Should have exactly one log line (no backtrace)
    lines = output.strip.split("\n")
    assert_equal 1, lines.size
  end

  test "Rails.error.report routes through subscriber" do
    output = capture_log do
      Rails.error.report(MapwiseError.new("test dispatch", context: { foo: 1 }), handled: true, source: "dispatch_test")
    end

    assert_includes output, "[#{Branding.app_name}]"
    assert_includes output, "test dispatch"
  end

  private

  def capture_log(&block)
    old_logger = Rails.logger
    io = StringIO.new
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = old_logger
  end
end

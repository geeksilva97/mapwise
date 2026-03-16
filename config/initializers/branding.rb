module Branding
  class << self
    def app_name
      Rails.application.config.app_name
    end

    def mailer_from_address
      Rails.application.config.mailer_from_address
    end

    def mailer_from
      "#{app_name} <#{mailer_from_address}>"
    end

    def theme_color
      Rails.application.config.theme_color
    end
  end
end

Rails.application.config.app_name = ENV.fetch("APP_NAME", "MapWise")
Rails.application.config.mailer_from_address = ENV.fetch("MAILER_FROM_ADDRESS", "noreply@example.com")
Rails.application.config.theme_color = ENV.fetch("THEME_COLOR", "#2563eb")

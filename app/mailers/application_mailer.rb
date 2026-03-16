class ApplicationMailer < ActionMailer::Base
  default from: -> { Branding.mailer_from }
  layout "mailer"
end

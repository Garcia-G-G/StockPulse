class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("EMAIL_FROM", "stockpulse@example.com")
  layout "mailer"
end

# frozen_string_literal: true

RSpec.shared_context "authenticated request" do
  let(:current_user) { create(:user) }

  before do
    # Set Telegram chat ID header for API auth
    if defined?(headers)
      headers["X-Telegram-Chat-Id"] = current_user.telegram_chat_id
    end
  end
end

# frozen_string_literal: true

RSpec.shared_examples "paginated endpoint" do |path|
  it "returns paginated results" do
    get path, headers: { "X-Telegram-Chat-Id" => current_user.telegram_chat_id }
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body).to have_key("data")
  end
end

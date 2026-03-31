# frozen_string_literal: true

# == Schema Information
#
# Table name: alerts
#
#  id                    :bigint           not null, primary key
#  ai_analysis_enabled   :boolean          default(TRUE), not null
#  alert_type            :enum             not null
#  condition             :jsonb            not null
#  cooldown_minutes      :integer          default(15), not null
#  is_enabled            :boolean          default(TRUE), not null
#  is_one_time           :boolean          default(FALSE), not null
#  last_triggered_at     :datetime
#  max_triggers          :integer
#  notes                 :text
#  notification_channels :string           default(["telegram"]), is an Array
#  symbol                :string(10)       not null
#  trigger_count         :integer          default(0), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  user_id               :bigint           not null
#
# Indexes
#
#  index_alerts_on_alert_type              (alert_type)
#  index_alerts_on_symbol_and_is_enabled   (symbol,is_enabled)
#  index_alerts_on_user_id                 (user_id)
#  index_alerts_on_user_id_and_is_enabled  (user_id,is_enabled)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class AlertSerializer
  include JSONAPI::Serializer

  attributes :symbol, :alert_type, :condition, :notification_channels, :cooldown_minutes,
             :is_enabled, :is_one_time, :last_triggered_at, :trigger_count, :max_triggers,
             :ai_analysis_enabled, :notes, :created_at
end

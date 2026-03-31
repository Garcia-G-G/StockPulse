# frozen_string_literal: true

# == Schema Information
#
# Table name: alert_histories
#
#  id                   :bigint           not null, primary key
#  ai_analysis          :text
#  ai_importance_score  :integer
#  alert_type           :string           not null
#  change_percent       :decimal(8, 4)
#  condition_snapshot   :jsonb            not null
#  indicator_values     :jsonb
#  notification_results :jsonb            not null
#  previous_price       :decimal(12, 4)
#  price_at_trigger     :decimal(12, 4)   not null
#  symbol               :string           not null
#  triggered_at         :datetime         not null
#  volume_at_trigger    :bigint
#  alert_id             :bigint           not null
#  user_id              :bigint           not null
#
# Indexes
#
#  index_alert_histories_on_alert_id                  (alert_id)
#  index_alert_histories_on_symbol_and_triggered_at   (symbol,triggered_at)
#  index_alert_histories_on_triggered_at              (triggered_at)
#  index_alert_histories_on_user_id                   (user_id)
#  index_alert_histories_on_user_id_and_triggered_at  (user_id,triggered_at)
#
# Foreign Keys
#
#  fk_rails_...  (alert_id => alerts.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class AlertHistorySerializer
  include JSONAPI::Serializer

  attributes :symbol, :alert_type, :triggered_at, :price_at_trigger, :previous_price,
             :change_percent, :volume_at_trigger, :indicator_values, :condition_snapshot,
             :notification_results, :ai_analysis, :ai_importance_score
end

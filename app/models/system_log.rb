# frozen_string_literal: true

# == Schema Information
#
# Table name: system_logs
#
#  id         :bigint           not null, primary key
#  component  :string           not null
#  details    :jsonb
#  level      :string           not null
#  message    :text             not null
#  created_at :datetime         not null
#
# Indexes
#
#  index_system_logs_on_component_and_created_at  (component,created_at)
#  index_system_logs_on_level_and_created_at      (level,created_at)
#
class SystemLog < ApplicationRecord
  LEVELS = %w[info warning error critical].freeze

  validates :level, presence: true, inclusion: { in: LEVELS }
  validates :component, presence: true
  validates :message, presence: true

  scope :errors, -> { where(level: %w[error critical]) }
  scope :for_component, ->(component) { where(component: component) }
  scope :recent, -> { order(created_at: :desc) }

  def self.log(level:, component:, message:, details: nil)
    create!(level: level, component: component, message: message, details: details)
  end
end

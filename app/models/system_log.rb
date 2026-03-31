# frozen_string_literal: true

class SystemLog < ApplicationRecord
  validates :level, presence: true, inclusion: { in: %w[debug info warn error fatal] }
  validates :component, presence: true
  validates :message, presence: true

  scope :errors, -> { where(level: %w[error fatal]) }
  scope :for_component, ->(component) { where(component: component) }
  scope :recent, -> { order(created_at: :desc) }

  def self.log(level:, component:, message:, data: nil)
    create!(level: level, component: component, message: message, data: data)
  end
end

# frozen_string_literal: true

# Oj in Rails-compatible mode for faster ActiveSupport JSON serialization.
require "oj"

Oj.default_options = {
  mode: :rails,
  time_format: :ruby,
  second_precision: 3
}

Oj.optimize_rails

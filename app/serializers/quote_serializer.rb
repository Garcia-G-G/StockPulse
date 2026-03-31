# frozen_string_literal: true

class QuoteSerializer
  include JSONAPI::Serializer

  attributes :symbol, :c, :d, :dp, :h, :l, :o, :pc, :t
end

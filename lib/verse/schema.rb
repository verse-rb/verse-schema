# frozen_string_literal: true

require_relative "schema/version"

module Verse
  module Schema
    module_function

    require_relative "schema/base"
    require_relative "schema/coalescer"
    require_relative "schema/post_processor"

    IDENTITY_PP = PostProcessor.new { |value| value }

    def define(&block)
      Base.new(&block)
    end

    def rule(message, &block)
      PostProcessor.new do |value, error|
        error.call(message) unless block.call(value, error)
        value
      end
    end
  end
end

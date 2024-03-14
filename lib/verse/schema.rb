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
        case block.arity
        when 1, -1, -2
          error.call(message) unless block.call(value)
        when 2
          error.call(message) unless block.call(value, error)
        else
          raise ArgumentError, "invalid block arity"
        end

        value
      end
    end
  end
end

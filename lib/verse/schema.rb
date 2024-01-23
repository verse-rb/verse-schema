# frozen_string_literal: true

require_relative "schema/version"

module Verse
  module Schema
    module_function

    def define(&block)
      Base.new(&block)
    end

    def rule(message, &block)
      Rule.new(message, block)
    end
  end
end

require_relative "schema/base"
require_relative "schema/coalescer"
require_relative "schema/rule"
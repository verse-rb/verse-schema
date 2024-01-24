# frozen_string_literal: true

module Verse
  module Schema
    class Rule
      attr_reader :message, :assertion

      def initialize(message, assertion)
        @message = message
        @assertion = assertion
      end

      def call(value, output, error_builder)
        @assertion.call(value, output, error_builder)
      end
    end
  end
end

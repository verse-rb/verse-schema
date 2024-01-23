# frozen_string_literal: true

module Verse
  module Schema
    class Rule
      attr_reader :message
      attr_reader :assertion

      def initialize(message, assertion)
        @message = message
        @assertion = assertion
      end

      def call(value, output)
        @assertion.call(value, output)
      end
    end
  end
end

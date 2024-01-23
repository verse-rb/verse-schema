# frozen_string_literal: true

module Verse
  module Schema
    class Result
      attr_reader :value, :errors

      def initialize(value, errors)
        @value = value
        @errors = errors
      end

      def success?
        errors.empty?
      end

      def fail?
        !success?
      end
    end
  end
end

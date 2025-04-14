# frozen_string_literal: true

module Verse
  module Schema
    # Result is a simple value object that holds the result of a validation
    # process. It has a value and can have a list of errors.
    # When the list of errors is empty, the result is considered successful and
    # passed through all the steps of validation and transformation.
    # When the list of errors is not empty, the result is considered failed and
    # the value might not have passed through all the transformation steps.
    class Result
      attr_reader :value, :errors

      def initialize(value, errors)
        @value = value
        @errors = errors
      end

      def success?
        errors.empty?
      end

      alias_method :valid?, :success?

      def fail?
        !success?
      end
    end
  end
end

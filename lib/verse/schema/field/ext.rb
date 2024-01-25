# frozen_string_literal: true

module Verse
  module Schema
    class Field
      def filled(message = "must be filled")
        rule(message) do |value, _output|
          if value.respond_to?(:empty?)
            !value.empty?
          elsif !value
            false
          else
            true
          end
        end
      end

      def in?(values, message="must be one of %s")
        values = [values] unless values.is_a?(Array)

        rule(message % values.join(", ")) do |value, _output|
          values.include?(value)
        end
      end

    end
  end
end

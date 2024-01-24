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
    end
  end
end

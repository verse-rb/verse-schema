module Verse
  module Schema
    class Field

      def filled(message = "must be filled")
        rule(message) do |value, output|
          value.is_a?(String) && !value.empty?
        end
      end

    end
  end
end

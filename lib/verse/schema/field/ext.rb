module Verse
  module Schema
    class Field

      def filled(message = "must be filled")
        rule(message) do |value, output|
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

module Verse
  module Schema
    class Field

      def filled
        rule("must be filled") do |value, output|
          if value.nil? || value.empty?
            output.add_error(message)
          end
        end
      end

    end
  end
end

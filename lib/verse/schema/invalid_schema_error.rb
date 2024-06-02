module Verse
  module Schema
    class InvalidSchemaError < StandardError
      attr_reader :errors

      def initialize(errors)
        @errors = errors

        errors = errors.map{|k, v|   "#{k}: #{v}" }.join("\n")
        message = "Invalid schema:\n#{errors}"

        super(message)
      end

    end
  end
end

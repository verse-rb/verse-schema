# frozen_string_literal: true

require "forwardable"

module Verse
  module Schema
    # Abstract base class for all schema-generated data classes.
    # Subclasses are created by calling `dataclass` on a Struct, Collection,
    # or Dictionary schema object.
    #
    # Usage:
    #   MyDataclass.new(input)                    # validates (default)
    #   MyDataclass.new(input, validate: false)   # skips validation (from_raw)
    #
    class Dataclass
      class << self
        # @return [Verse::Schema::Base] The schema used for validation
        attr_reader :schema
      end
    end
  end
end

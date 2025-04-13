# frozen_string_literal: true

require_relative "./field"
require_relative "./result"
require_relative "./error_builder"
require_relative "./post_processor"
require_relative "./invalid_schema_error"

module Verse
  module Schema
    # Abstract base class for all schemas types.
    class Base
      attr_reader :post_processors

      # Initialize a new schema.
      def initialize(post_processors: nil)
        @post_processors   = post_processors
      end

      def rule(fields = nil, message = "rule failed", &block)
        pp = PostProcessor.new do |value, error|
          case block.arity
          when 1, -1, -2 # -1/-2 are for dealing with &:method block.
            error.add(fields, message) unless instance_exec(value, &block)
          when 2
            error.add(fields, message) unless instance_exec(value, error, &block)
          else
            # :nocov:
            raise ArgumentError, "invalid block arity"
            # :nocov:
          end

          value
        end

        if @post_processors
          @post_processors.attach(pp)
        else
          @post_processors = pp
        end

        self
      end

      def transform(&block)
        callback = proc do |value, error_builder|
          stop if error_builder.errors.any?
          instance_exec(value, error_builder, &block)
        end

        if @post_processors
          @post_processors.attach(
            PostProcessor.new(&callback)
          )
        else
          @post_processors = PostProcessor.new(&callback)
        end

        self
      end

      def valid?(input) = validate(input).success?

      def validate(input, error_builder: nil, locals: {}) = raise NotImplementedError

      def new(arg)
        result = validate(arg)
        return result.value if result.success?

        raise InvalidSchemaError, result.errors
      end
    end
  end
end

require_relative "./collection"
require_relative "./dictionary"
require_relative "./scalar"
require_relative "./selector"
require_relative "./struct"

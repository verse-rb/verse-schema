# frozen_string_literal: true

require_relative "schema/version"

module Verse
  module Schema
    module_function

    require_relative "schema/base"
    require_relative "schema/coalescer"
    require_relative "schema/post_processor"
    require_relative "schema/json"

    def define(from = nil, &block)
      if from
        schema = from.dup
        schema.instance_eval(&block) if block_given?
        schema
      else
        Struct.new(&block)
      end
    end

    # Define the schema as an array of values
    def array(*values, &block)
      if block_given?
        raise ArgumentError, "array of value cannot be used with a block" unless values.empty?

        Collection.new(values: [define(&block)])
      else
        raise ArgumentError, "block or type is required" if values.empty?

        Collection.new(values:)
      end
    end

    def dictionary(*values, &block)
      if block_given?
        raise ArgumentError, "array of value cannot be used with a block" unless values.empty?

        Dictionary.new(values: [define(&block)])
      else
        raise ArgumentError, "block or type is required" if values.empty?

        Dictionary.new(values:)
      end
    end

    def scalar(*values) = Scalar.new(values:)
    def selector(**values) = Selector.new(values:)

    def empty
      @empty ||= begin
        empty_schema = Verse::Schema.define
        empty_schema.dataclass # Generate the dataclass
        empty_schema.freeze # Freeze to avoid modification
        empty_schema
      end
    end

    def rule(message, &block)
      PostProcessor.new do |value, error|
        case block.arity
        when 1, -1, -2
          error.add(opts[:key], message) unless block.call(value)
        when 2
          error.add(opts[:key], message) unless block.call(value, error)
        else
          raise ArgumentError, "invalid block arity"
        end

        value
      end
    end
  end
end

# frozen_string_literal: true

require_relative "schema/version"

module Verse
  module Schema
    module_function

    require_relative "schema/base"
    require_relative "schema/coalescer"
    require_relative "schema/post_processor"

    IDENTITY_PP = PostProcessor.new { |value| value }

    def define(from = nil, &block)
      if from
        schema = from.dup
        schema.instance_eval(&block)
        schema
      else
        Struct.new(&block)
      end
    end

    # Define the schema as an array of values
    def array(*types, &block)
      if block_given?
        raise ArgumentError, "array of value cannot be used with a block" unless types.empty?

        Collection.new(values: [define(&block)])
      else
        raise ArgumentError, "block or type is required" if types.empty?

        Collection.new(values: types)
      end
    end

    def dictionary(*types, &block)
      if block_given?
        raise ArgumentError, "array of value cannot be used with a block" unless types.empty?

        Dictionary.new(values: [define(&block)])
      else
        raise ArgumentError, "block or type is required" if types.empty?

        Dictionary.new(values: types)
      end
    end

    def scalar(*types)
      Verse::Schema::Scalar.new(values: types)
    end

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

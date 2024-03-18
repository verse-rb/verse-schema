# frozen_string_literal: true

require_relative "./field"
require_relative "./result"
require_relative "./error_builder"
require_relative "./post_processor"

module Verse
  module Schema
    class Base
      attr_reader :fields, :post_processors

      def initialize(&block)
        @fields = []
        @post_processors = IDENTITY_PP.dup
        instance_eval(&block)
      end

      def extend(another_schema)
        @fields += another_schema.fields
        @post_processors = another_schema.post_processors
      end

      def rule(fields, message = "rule failed", &block)
        @post_processors.attach(
          PostProcessor.new do |value, error|
            case block.arity
            when 1, -1, -2 # -1/-2 are for dealing with &:method block.
              error.add(fields, message) unless block.call(value)
            when 2
              error.add(fields, message) unless block.call(value, error)
            else
              raise ArgumentError, "invalid block arity"
            end

            value
          end
        )
      end

      def define(&block)
        Verse::Schema.define(&block)
      end

      def transform(&block)
        callback = proc do |value, error_builder|
          next value if error_builder.errors.any?
          block.call(value, error_builder)
        end

        @post_processors.attach(
          PostProcessor.new(&callback)
        )
      end

      def field(field_name, type = Object, **opts, &block)
        field = Field.new(field_name, type, opts, &block)
        @fields << field
        field
      end

      def field?(field_name, type = Object, **opts, &block)
        field(field_name, type, **opts, &block).optional
      end

      def extra_fields
        @extra_fields = true
      end

      def valid?(input)
        validate(input).success?
      end

      def validate(input, error_builder = nil)
        error_builder ||= ErrorBuilder.new

        output = {}

        @fields.each do |field|
          exists = input.key?(field.key.to_s) || input.key?(field.key.to_sym)

          if exists
            value = input[field.key.to_s] || input[field.key.to_sym]
            field.apply(value, output, error_builder)
          elsif field.default?
            field.apply(field.default, output, error_builder)
          elsif field.required?
            error_builder.add(field.key, "is required")
          end
        end

        if @extra_fields
          input.each do |key, value|
            output[key.to_sym] = value unless @fields.any? { |field| field.key.to_s == key.to_s }
          end
        end

        output = @post_processors.call(output, nil, error_builder) if error_builder.errors.empty?

        Result.new(output, error_builder.errors)
      end
    end
  end
end

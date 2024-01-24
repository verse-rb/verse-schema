# frozen_string_literal: true

require_relative "./field"
require_relative "./result"
require_relative "./error_builder"
require_relative "./post_processor"

module Verse
  module Schema
    class Base
      attr_reader :fields

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
            error.call(message, fields) unless block.call(value, error)
            value
          end
        )
      end

      def transform(&block)
        @post_processors.attach(
          PostProcessor.new(&block)
        )
      end

      def field(field_name, type, **opts, &block)
        field = Field.new(field_name, type, opts, &block)
        @fields << field
        field
      end

      def field?(field_name, type, **opts, &block)
        field(field_name, type, **opts, &block).optional
      end

      def extra_fields
        @extra_fields = true
      end

      def validate(input, error_builder = nil)
        error_builder ||= ErrorBuilder.new

        output = {}

        @fields.each do |field|
          exists = input.key?(field.key.to_s) || input.key?(field.key.to_sym)

          if exists
            value = input[field.key.to_s] || input[field.key.to_sym]
            field.apply(value, output, error_builder)
          elsif field.required?
            error_builder.add(field.key, "is required")
          end
        end

        if @extra_fields
          input.each do |key, value|
            output[key.to_sym] = value unless @fields.any? { |field| field.key.to_s == key.to_s }
          end
        end

        if error_builder.errors.empty?
          output = @post_processors.call(output, nil, error_builder)
        end

        Result.new(output, error_builder.errors)
      end
    end
  end
end

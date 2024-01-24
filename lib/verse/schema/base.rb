# frozen_string_literal: true

require_relative "./field"
require_relative "./result"
require_relative "./error_builder"
require_relative "./rule"

module Verse
  module Schema
    class Base
      def initialize(&block)
        @fields = []
        @rules = []
        instance_eval(&block)
      end

      def extend(another_schema)
        @fields += another_schema.fields
        @rules += another_schema.rules
      end

      def rule(fields, message="rule failed", &block)
        fields = [fields] unless fields.is_a?(Array)
        @rules << [fields, Rule.new(message, block)]
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

        @rules.each do |fields, rule|
          if fields.all? { |field| output.key?(field) }
            unless rule.call(output, output, error_builder)
              fields.each do |f|
                error_builder.add(f, rule.message)
              end
            end
          end
        end

        if @extra_fields
          input.each do |key, value|
            unless @fields.any? { |field| field.key.to_s == key.to_s }
              output[key.to_sym] = value
            end
          end
        end

        Result.new(output, error_builder.errors)
      end
    end
  end
end

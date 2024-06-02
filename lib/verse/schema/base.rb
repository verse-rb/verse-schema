# frozen_string_literal: true

require_relative "./field"
require_relative "./result"
require_relative "./error_builder"
require_relative "./post_processor"
require_relative "./invalid_schema_error"

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

      def rule(fields = nil, message = "rule failed", &block)
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
          stop if error_builder.errors.any?
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

      def validate(input, error_builder: nil, locals: {})
        locals = locals.dup # Ensure they are not modified

        error_builder = \
          case error_builder
          when String
            ErrorBuilder.new(error_builder)
          when ErrorBuilder
            error_builder
          else
            ErrorBuilder.new
          end

        output = {}

        @fields.each do |field|
          exists = input.key?(field.key.to_s) || input.key?(field.key.to_sym)

          if exists
            value = input.fetch(field.key.to_s, input[field.key.to_sym])
            field.apply(value, output, error_builder, locals)
          elsif field.default?
            field.apply(field.default, output, error_builder, locals)
          elsif field.required?
            error_builder.add(field.key, "is required")
          end
        end

        if @extra_fields
          input.each do |key, value|
            output[key.to_sym] = value unless @fields.any? { |field| field.key.to_s == key.to_s }
          end
        end

        output = @post_processors.call(output, nil, error_builder, **locals) if error_builder.errors.empty?

        Result.new(output, error_builder.errors)
      end

      # Represent a dataclass using schema internally
      def dataclass
        schema = self

        @dataclass ||= Data.define(
          *fields.map(&:name)
        ) do
          define_method(:initialize) do |**hash|
            result = schema.validate(hash)

            unless result.success?
              raise InvalidSchemaError, result.errors
            end

            value = result.value

            schema.fields.each do |f|
              data = value[f.name]

              next unless data

              if f.type.is_a?(Verse::Schema::Base)
                value[f.name] = f.type.dataclass.new(**data)
              end
            end

            super(**value)
          end

        end
      end

    end
  end
end

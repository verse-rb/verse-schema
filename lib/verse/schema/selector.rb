# frozen_string_literal: true

require_relative "./base"

module Verse
  module Schema
    class Selector < Base
      attr_accessor :values

      # Initialize a new selector schema.
      # Selector schema will select a subset of the input based on the provided values.
      #
      # @param values [Hash<Symbol, Class|Array<Class>>] Selected values of the selector schema.
      # @param post_processors [PostProcessor] The post processors to apply.
      #
      # @return [Selector] The new dictionary.
      def initialize(values:, post_processors: nil)
        super(post_processors:)

        @values    = values.transform_values{ |v| v.is_a?(Array) ? v : [v] }
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

        locals[:__path__] ||= []

        validate_selector(input, error_builder, locals)
      end

      def dup
        Base.new(
          values: @values.dup,
          post_processors: @post_processors&.dup
        )
      end

      def inherit?(parent_schema)
        # Check if parent_schema is a Base and if all parent fields are present in this schema
        return false unless parent_schema.is_a?(Selector)

        @values.all? do |key, value|
          # Check if the key exists in the parent schema and if the value is a subclass of the parent value
          parent_value = parent_schema.values[key]
          next false unless parent_value

          (parent_value & value).size == parent_schema.size
        end
      end

      def <=(other)
        other == self || inherit?(other)
      end

      def <(other)
        other != self && inherit?(other)
      end

      # rubocop:disable Style/InverseMethods
      def >(other)
        !self.<=(other)
      end
      # rubocop:enable Style/InverseMethods

      # Aggregation of two schemas.
      def +(other)
        raise ArgumentError, "aggregate must be a selector" unless other.is_a?(Selector)

        new_classes = @values.merge(other.values) do |_key, old_value, new_value|
          # Merge the arrays of classes
          (old_value + new_value).uniq
        end

        new_post_processors = @post_processors&.dup

        if other.post_processors
          if new_post_processors
            new_post_processors.attach(other.post_processors)
          else
            new_post_processors = other.post_processors.dup
          end
        end

        Selector.new(
          values: new_classes,
          post_processors: new_post_processors
        )
      end

      def dataclass_schema
        return @dataclass_schema if @dataclass_schema

        @dataclass_schema = dup

        @dataclass_schema.values = @dataclass_schema.values.transform_values do |value|
          if value.is_a?(Array)
            value.map do |v|
              if v.is_a?(Base)
                v.dataclass_schema
              else
                v
              end
            end
          elsif value.is_a?(Base)
            value.dataclass_schema
          else
            value
          end
        end
      end

      protected

      def validate_selector(input, error_builder, locals)
        output = {}

        selector = locals.fetch(:selector) do
          error_builder.add(
            nil, "selector not provided for this schema", **locals
          )

          return Result.new(nil, error_builder.errors)
        end

        fetched_values = @values.fetch(selector) do
          @values.fetch(:__else__) do
            error_builder.add(
              nil,
              "selector `#{selector}` is not valid for this schema",
              **locals
            )

            return Result.new(output, error_builder.errors)
          end
        end

        coalesced_value = nil

        begin
          coalesced_value =
            Coalescer.transform(
              input,
              fetched_values,
              nil,
              locals:
            )

          if coalesced_value.is_a?(Result)
            error_builder.combine(nil, coalesced_value.errors)
            coalesced_value = coalesced_value.value
          end
        rescue Coalescer::Error => e
          error_builder.add(nil, e.message, **locals)
        end

        Result.new(coalesced_value, error_builder.errors)
      end
    end
  end
end

# frozen_string_literal: true

require_relative "./base"

module Verse
  module Schema
    class Scalar < Base
      attr_accessor :values

      # Initialize a new schema.
      #
      # @param values [Array<Class>] The classes allowed for this scalar.
      # @param post_processors [PostProcessor] The post processors to apply.
      #
      # @return [Scalar] The new schema.
      def initialize(
        values:,
        post_processors: nil
      )
        super(post_processors:)
        @values = values
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

        validate_scalar(input, error_builder, locals)
      end

      def dup
        Scalar.new(
          values: @values.dup,
          post_processors: @post_processors&.dup
        )
      end

      def inherit?(parent_schema)
        return false unless parent_schema.is_a?(Scalar)

        # Check that all the values in the parent schema are present in the
        # current schema
        parent_schema.values.all? do |parent_value|
          @values.any? do |child_value|
            if (child_value.is_a?(Base) && parent_value.is_a?(Base)) ||
                (child_value.is_a?(Class) && parent_value.is_a?(Class))
              puts "#{child_value} <= #{parent_value}: #{child_value <= parent_value}"
              # Both are schema instances, use their inherit? method
              child_value <= parent_value
            else
              # Mixed types or non-inheritable types, cannot inherit
              false
            end
          end
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
        raise ArgumentError, "aggregate must be a scalar" unless other.is_a?(Scalar)

        new_classes = (@values + other.values).uniq
        new_post_processors = @post_processors&.dup

        if other.post_processors
          if new_post_processors
            new_post_processors.attach(other.post_processors)
          else
            new_post_processors = other.post_processors.dup
          end
        end

        Scalar.new(
          values: new_classes,
          post_processors: new_post_processors
        )
      end

      def dataclass_schema
        return @dataclass_schema if @dataclass_schema

        @dataclass_schema = dup

        values = @dataclass_schema.values

        @dataclass_schema.values = values.map do |value|
          if value.is_a?(Base)
            value.dataclass_schema
          else
            value
          end
        end

        @dataclass_schema
      end

      protected

      def validate_scalar(input, error_builder, locals)
        coalesced_value = nil

        begin
          coalesced_value =
            Coalescer.transform(
              input,
              @values,
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

        if @post_processors && error_builder.errors.empty?
          coalesced_value = @post_processors.call(coalesced_value, nil, error_builder, **locals)
        end

        Result.new(coalesced_value, error_builder.errors)
      end
    end
  end
end

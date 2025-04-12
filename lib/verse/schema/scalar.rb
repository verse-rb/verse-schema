# frozen_string_literal: true

require_relative "./base"

module Verse
  module Schema
    class Scalar < Base
      attr_reader :values

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
        @values    = values
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
        Collection.new(
          values: @values.dup,
          post_processors: @post_processors&.dup
        )
      end

      def inherit?(parent_schema)
        # Check if parent_schema is a Base and if all parent fields are present in this schema
        parent_schema.is_a?(Scalar) &&
          (
            parent_schema.values & @values
          ).size == parent_schema.values.size
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
        raise ArgumentError, "aggregate must be a collection" unless other.is_a?(Collection)

        new_classes = @values + other.values
        new_post_processors = @post_processors&.dup

        if other.post_processors
          if new_post_processors
            new_post_processors.attach(other.post_processors)
          else
            new_post_processors = other.post_processors.dup
          end
        end

        Collection.new(
          values: new_classes,
          post_processors: new_post_processors
        )
      end

      protected

      def validate_scalar(input, error_builder, locals)
        coalesced_value = nil

        begin
          coalesced_value =
            Coalescer.transform(
              input,
              @values,
              @opts,
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

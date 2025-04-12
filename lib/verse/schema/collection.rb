# frozen_string_literal: true

require_relative "./base"

module Verse
  module Schema
    class Collection < Base
      attr_reader :values

      # Initialize a new collection schema.
      #
      # @param values [Array<Class>] The scalar classes of the schema, if type is :array, :dictionary.or :scalar.
      # @param post_processors [PostProcessor] The post processors to apply.
      #
      # @return [Collection] The new schema.
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

        validate_array(input, error_builder, locals)
      end

      def dup
        Collection.new(
          values: @values.dup,
          post_processors: @post_processors&.dup
        )
      end

      def inherit?(parent_schema)
        # Check if parent_schema is a Base and if all parent fields are present in this schema
        parent_schema.is_a?(Collection) &&
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

      def validate_array(input, error_builder, locals)
        locals[:__path__] ||= []

        output = []

        unless input.is_a?(Array)
          error_builder.add(nil, "must be an array")
          return Result.new(output, error_builder.errors)
        end

        input.each_with_index do |value, index|
          locals[:__path__].push(index)

          coalesced_value =
            Coalescer.transform(
              value,
              @values,
              @opts,
              locals:
            )

          if coalesced_value.is_a?(Result)
            error_builder.combine(index, coalesced_value.errors)
            coalesced_value = coalesced_value.value
          end

          output << coalesced_value

          locals[:__path__].pop
        rescue Coalescer::Error => e
          error_builder.add(index, e.message, **locals)
        end

        Result.new(output, error_builder.errors)
      end
    end
  end
end

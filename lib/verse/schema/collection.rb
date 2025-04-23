# frozen_string_literal: true

require_relative "./base"

module Verse
  module Schema
    class Collection < Base
      attr_accessor :values

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

      def validate(input, error_builder: nil, locals: {}, strict: false)
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

        validate_array(input, error_builder, locals, strict)
      end

      def dup
        Collection.new(
          values: @values.dup,
          post_processors: @post_processors&.dup
        )
      end

      def inherit?(parent_schema)
        # Check if parent_schema is a Collection
        return false unless parent_schema.is_a?(Collection)

        # If the child collection allows nothing (@values empty), it trivially inherits from any parent collection.
        return true if @values.empty?
        # If the parent collection allows nothing, but the child allows something, it cannot inherit.
        return false if parent_schema.values.empty?

        # Check if *every* type allowed by this child collection (`@values`)...
        @values.all? do |child_type|
          # ...is a subtype (`<=`) of *at least one* type allowed by the parent collection.
          parent_schema.values.any? do |parent_type|
            # Use the existing `<=` operator defined on schema types (Scalar, Struct, etc.)
            # This assumes the `<=` operator correctly handles class inheritance (e.g., Integer <= Object)
            # and schema type compatibility.
            child_type <= parent_type
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

      def dataclass_schema
        return @dataclass_schema if @dataclass_schema

        @dataclass_schema = dup

        values = @dataclass_schema.values

        if values.is_a?(Array)
          @dataclass_schema.values = values.map do |value|
            if value.is_a?(Base)
              value.dataclass_schema
            else
              value
            end
          end
        elsif values.is_a?(Base)
          @dataclass_schema.values = values.dataclass_schema
        end

        @dataclass_schema
      end

      def inspect
        types_string = @values.map(&:inspect).join("|")
        # Use ::collection to distinguish from Scalar's inspect
        "#<collection<#{types_string}> 0x#{object_id.to_s(16)}>"
      end

      protected

      def validate_array(input, error_builder, locals, strict)
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
              locals:,
              strict:
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

        if @post_processors && error_builder.errors.empty?
          output = @post_processors.call(output, nil, error_builder, **locals)
        end

        Result.new(output, error_builder.errors)
      end

    end
  end
end

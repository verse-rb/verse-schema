# frozen_string_literal: true

require_relative "./base"

module Verse
  module Schema
    class Dictionary < Base
      attr_accessor :values

      # Initialize a new dictionary.
      # @param values [Array<Class>] The allowed values of the dictionary.
      # @param post_processors [PostProcessor] The post processors to apply.
      # @return [Dictionary] The new dictionary.
      def initialize(values:, post_processors: nil)
        super(post_processors:)

        @values    = values
      end

      def transform(&block)
        callback = proc do |value, error_builder|
          stop if error_builder.errors.any?
          instance_exec(value, error_builder, &block)
        end

        @post_processors ||= IDENTITY_PP.dup
        @post_processors.attach(
          PostProcessor.new(&callback)
        )
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

        validate_dictionary(input, error_builder, locals)
      end

      def dup
        Dictionary.new(
          values: @values.dup,
          post_processors: @post_processors&.dup
        )
      end

      def inherit?(parent_schema)
        # Check if parent_schema is a Base and if all parent fields are present in this schema
        parent_schema.is_a?(Dictionary) &&
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
        raise ArgumentError, "aggregate must be a dictionary" unless other.is_a?(Dictionary)

        new_classes = @values + other.values
        new_post_processors = @post_processors&.dup

        if other.post_processors
          if new_post_processors
            new_post_processors.attach(other.post_processors)
          else
            new_post_processors = other.post_processors.dup
          end
        end

        Dictionary.new(
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

      protected

      def validate_dictionary(input, error_builder, locals)
        output = {}

        unless input.is_a?(Hash)
          error_builder.add(nil, "must be a hash")
          return Result.new(output, error_builder.errors)
        end

        input.each do |key, value|
          key_sym = key.to_sym
          locals[:__path__].push(key_sym)

          coalesced_value =
            Coalescer.transform(
              value,
              @values,
              @opts,
              locals:
            )

          if coalesced_value.is_a?(Result)
            error_builder.combine(key, coalesced_value.errors)
            coalesced_value = coalesced_value.value
          end

          output[key.to_sym] = coalesced_value
          locals[:__path__].pop
        rescue Coalescer::Error => e
          error_builder.add(key, e.message, **locals)
        end

        Result.new(output, error_builder.errors)
      end
    end
  end
end

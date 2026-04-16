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

        locals[:__path__] ||= []

        validate_dictionary(input, error_builder, locals, strict)
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
              value.respond_to?(:dataclass) ? value.dataclass : value.dataclass_schema
            else
              value
            end
          end
        elsif values.is_a?(Base)
          @dataclass_schema.values = values.respond_to?(:dataclass) ? values.dataclass : values.dataclass_schema
        end

        @dataclass_schema
      end

      # Create a value object class from the schema.
      # Returns a Verse::Schema::Dataclass subclass wrapping a Hash.
      # Includes Enumerable and delegates common Hash methods.
      #
      # @param block [Proc] Optional block evaluated in the context of the new class.
      # @return [Class<Verse::Schema::Dataclass>] The generated dataclass.
      def dataclass(&block)
        return @dataclass if @dataclass

        # Create the class early so recursive schemas can reference it
        @dataclass = Class.new(Dataclass)

        # Build dataclass_schema (may recursively trigger nested dataclass creation)
        dc_schema = self.dataclass_schema

        @dataclass.class_eval do
          include Enumerable
          extend Forwardable

          def_delegators :@data, :[], :fetch, :key?, :has_key?, :keys, :values, :size, :empty?

          define_singleton_method(:schema) { dc_schema }

          define_singleton_method(:from_raw) do |data|
            instance = allocate
            instance.instance_variable_set(:@data, data.freeze)
            instance.freeze
            instance
          end

          define_singleton_method(:new) do |input, validate: true|
            unless validate
              return from_raw(input)
            end

            result = dc_schema.validate(input)

            if result.success?
              from_raw(result.value)
            else
              raise InvalidSchemaError, result.errors
            end
          end

          define_method(:each) { |&blk| @data.each(&blk) }

          define_method(:to_h) { @data.dup }

          define_method(:==) do |other|
            case other
            when self.class then @data == other.to_h
            when Hash then @data == other
            else false
            end
          end
          alias_method :eql?, :==

          define_method(:hash) { [self.class, @data].hash }

          define_method(:inspect) { "#<dictionary #{@data.inspect}>" }
          alias_method :to_s, :inspect

          class_eval(&block) if block
        end

        @dataclass
      end

      def inspect(visited = Set.new)
        # Keys are always symbols, so only show value types.
        # Handle cases where values might be arrays (unions) or schema objects.
        value_types_string = (@values || [Object]).map { |v|
          v.is_a?(Base) ? v.inspect(visited) : v.inspect
        }.join("|")

        "#<dictionary<#{value_types_string}> 0x#{object_id.to_s(16)}>"
      end

      protected

      def validate_dictionary(input, error_builder, locals, strict)
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
              locals:,
              strict:
            )

          if coalesced_value.is_a?(Result)
            error_builder.combine(key, coalesced_value.errors)
            coalesced_value = coalesced_value.value
          end

          output[key_sym] = coalesced_value
        rescue Coalescer::Error => e
          error_builder.add(key, e.message, **locals)
        ensure
          locals[:__path__].pop
        end

        if @post_processors && error_builder.errors.empty?
          output = @post_processors.call(output, nil, error_builder, **locals)
        end

        Result.new(output, error_builder.errors)
      end
    end
  end
end

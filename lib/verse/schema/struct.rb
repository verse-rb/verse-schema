# frozen_string_literal: true

require_relative "./field"
require_relative "./result"
require_relative "./error_builder"
require_relative "./post_processor"
require_relative "./invalid_schema_error"

module Verse
  module Schema
    class Struct < Base
      attr_accessor :fields

      # Initialize a new schema.
      #
      # @param fields [Array<Field>] The fields of the schema.
      # @param post_processors [PostProcessor] The post processors to apply.
      # @param extra_fields [Boolean] Whether to allow extra fields.
      # @param block [Proc] The block to evaluate (DSL).
      #
      # @return [Struct] The new schema.
      def initialize(
        fields: [],
        post_processors: nil,
        extra_fields: false,

        &block
      )
        super(post_processors:)
        @fields            = fields
        @extra_fields      = extra_fields

        instance_eval(&block) if block_given?
      end

      # delegated method useful to write clean DSL
      def define(from = nil, &block)
        Verse::Schema.define(from, &block)
      end

      def field(field_name, type = Object, **opts, &block)
        if opts[:over] && @fields.none?{ |f| f.name == opts[:over] }
          # Ensure the `over` field exists and is
          # already defined.
          # There is some dependencies in validation,
          # and I think that's the best trade-off to
          # raise error early during schema definition.
          raise ArgumentError, "over field #{opts[:over]} must be defined before #{field_name}"
        end

        field = Field.new(field_name, type, opts, &block)
        @fields << field
        field
      end

      def field?(field_name, type = Object, **opts, &block)
        field(field_name, type, **opts, &block).optional
      end

      def extra_fields(value = true)
        @extra_fields = !!value
      end

      def extra_fields? = @extra_fields

      def valid?(input) = validate(input).success?

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

        unless input.is_a?(Hash)
          error_builder.add(nil, "must be a hash")
          return Result.new({}, error_builder.errors)
        end

        validate_hash(input, error_builder, locals)
      end

      def dup
        Struct.new(
          fields: @fields.map(&:dup),
          extra_fields: @extra_fields,
          post_processors: @post_processors&.dup
        )
      end

      def inherit?(parent_schema)
        # Check if parent_schema is a Struct and if all parent fields are present in this schema
        parent_schema.is_a?(Struct) &&
          parent_schema.fields.all? { |parent_field|
            child_field = @fields.find { |f2| f2.name == parent_field.name }
            child_field&.inherit?(parent_field)
          }
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
        raise ArgumentError, "aggregate must be a schema" unless other.is_a?(Struct)

        new_schema = dup

        other.fields.each do |f|
          field_index = new_schema.fields.find_index{ |f2| f2.name == f.name }

          if field_index
            field = new_schema.fields[field_index]

            field_type = \
              if field.type == f.type
                field.type
              else
                [field.type, f.type].flatten.uniq
              end

            if f.post_processors
              if field.post_processors
                field.post_processors.attach(f.post_processors)
              else
                field.post_processors = f.post_processors
              end
            end

            new_schema.fields[field_index] = Field.new(
              field.name,
              field_type,
              field.opts.merge(f.opts),
              post_processors: field.post_processors
            )
          else
            new_schema.fields << f.dup
          end
        end

        new_schema
      end

      def dataclass_schema
        return @dataclass_schema if @dataclass_schema

        @dataclass_schema = dup

        @dataclass_schema.fields = @dataclass_schema.fields.map do |field|
          type = field.type

          if type.is_a?(Array)
            field.type(type.map{ |t| t.is_a?(Base) ? t.dataclass_schema : t })
          elsif type.is_a?(Base)
            field.type(type.dataclass_schema)
          else
            field
          end
        end

        this = self
        fields_map = fields.map(&:name)

        @dataclass_schema.transform do |value|
          next value unless value.is_a?(Hash)

          if this.extra_fields?
            standard_fields = value.slice(*fields_map)
            extra_fields = value.except(*fields_map)

            this.dataclass.from_raw(**standard_fields, extra_fields:)
          else
            this.dataclass.from_raw(**value)
          end
        end
      end

      # Create a value object class from the schema.
      def dataclass(&block)
        return @dataclass if @dataclass

        fields = @fields.map(&:name)

        dataclass_schema = self.dataclass_schema

        fields << :extra_fields if extra_fields?

        value_object = ::Struct.new(*fields, keyword_init: true) do
          # Redefine new method
          define_singleton_method(:from_raw, &method(:new))

          define_singleton_method(:new) do |*args, **kwargs|
            # Use the schema to generate the hash for our record
            if args.size > 1
              raise ArgumentError, "You cannot pass more than one argument"
            end

            if args.size == 1
              if kwargs.any?
                raise ArgumentError, "You cannot pass both a hash and keyword arguments"
              end

              kwargs = args.first
            end

            dataclass_schema.new(kwargs)
          end

          define_singleton_method(:schema){ dataclass_schema }

          class_eval(&block) if block
        end

        @dataclass = value_object
      end


      protected

      def validate_hash(input, error_builder, locals)
        locals[:__path__] ||= []

        output = {}

        checked_fields = []

        @fields.each do |field|
          key_s = field.key.to_s
          key_sym = key_s.to_sym

          checked_fields << key_s << key_sym

          exists = true
          value = input.fetch(key_sym) { input.fetch(key_s) { exists = false } }

          begin
            locals[:__path__].push(key_sym)

            if field.opts[:over]
              locals[:selector] = output[field.opts[:over]]
            end

            if exists
              field.apply(value, output, error_builder, locals)
            elsif field.default?
              field.apply(field.default, output, error_builder, locals)
            elsif field.required?
              error_builder.add(field.key, "is required")
            end
          ensure
            # This is more performant than creating new array everytime,
            # but the local structure must be duplicated.
            locals[:__path__].pop
          end
        end

        if @extra_fields
          output.merge!(
            input.except(*checked_fields).transform_keys(&:to_sym)
          )
        end

        if @post_processors && error_builder.errors.empty?
          output = @post_processors.call(output, nil, error_builder, **locals)
        end

        Result.new(output, error_builder.errors)
      end
    end
  end
end

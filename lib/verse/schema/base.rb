# frozen_string_literal: true

require_relative "./field"
require_relative "./result"
require_relative "./error_builder"
require_relative "./post_processor"
require_relative "./invalid_schema_error"

module Verse
  module Schema
    class Base
      attr_reader :fields, :post_processors, :type, :scalar_classes

      # Initialize a new schema.
      # @param fields [Array<Field>] The fields of the schema.
      # @param type [Symbol] The type of the schema:
      #        - :hash simple hash schema, with field and value for each fields (default).
      #        - :array for an array schema, having value for each element matching scalar_classes parameter.
      #        - :dictionary for open symbolic key and value having value for each element matching scalar_classes parameter.
      #        - :scalar for a schema with a single scalar value.
      # @param scalar_classes [Array<Class>] The scalar classes of the schema, if type is :array, :dictionary.or :scalar.
      def initialize(
        fields: [],
        type: :hash,
        scalar_classes: nil,
        post_processors: nil,
        &block
      )
        @fields            = fields
        @post_processors   = post_processors
        @type              = type
        @scalar_classes = scalar_classes

        instance_eval(&block) if block_given?
      end

      def rule(fields = nil, message = "rule failed", &block)
        @post_processors ||= IDENTITY_PP.dup
        @post_processors.attach(
          PostProcessor.new do |value, error|
            case block.arity
            when 1, -1, -2 # -1/-2 are for dealing with &:method block.
              error.add(fields, message) unless instance_exec(value, &block)
            when 2
              error.add(fields, message) unless instance_exec(value, error, &block)
            else
              # :nocov:
              raise ArgumentError, "invalid block arity"
              # :nocov:
            end

            value
          end
        )
      end

      def self.define(from = nil, &block)
        if from
          new(
            fields: from.fields&.map(&:dup),
            type: from.type,
            scalar_classes: from.scalar_classes,
            post_processors: from.post_processors&.dup,
            &block
          )
        else
          new(&block)
        end
      end

      def self.define_array(*scalar_classes)
        new(
          type: :array,
          scalar_classes:
        )
      end

      def self.define_dictionary(*scalar_classes)
        new(
          type: :dictionary,
          scalar_classes:
        )
      end

      def self.define_scalar(*scalar_classes)
        new(
          type: :scalar,
          scalar_classes:,
        )
      end

      def define(from = nil, &block)
        self.class.define(from, &block)
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

      def extra_fields?
        !!@extra_fields
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

        locals[:__path__] ||= []

        case type
        when :array
          validate_array(input, error_builder, locals)
        when :dictionary
          validate_dictionary(input, error_builder, locals)
        when :scalar
          validate_scalar(input, error_builder, locals)
        when :hash
          validate_hash(input, error_builder, locals)
        end
      end

      def validate_array(input, error_builder, locals)
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
              @scalar_classes,
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

      def validate_scalar(input, error_builder, locals)
        coalesced_value = nil

        begin
          coalesced_value =
            Coalescer.transform(
              input,
              @scalar_classes,
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

      def dup
        Base.new(
          fields: @fields.map(&:dup),
          post_processors: @post_processors&.dup
        )
      end

      def inherit?(parent_schema)
        # Check if parent_schema is a Base and if all parent fields are present in this schema
        parent_schema.is_a?(Base) &&
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
        raise ArgumentError, "aggregate must be a schema" unless other.is_a?(Base)

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

      # Need data structure
      if RUBY_VERSION >= "3.2.0"
        # Represent a dataclass using schema internally
        def dataclass(&block)
          schema = self

          @dataclass ||= Data.define(
            *fields.map(&:name)
          ) do
            bare_new = singleton_method(:new)

            define_singleton_method(:from_raw) do |hash|
              # Set optional unset fields to `nil`
              (schema.fields.map(&:name) - hash.keys).map{ |k| hash[k] = nil }

              bare_new.call(**hash)
            end

            define_singleton_method(:new_sub_dataclass) do |type, value|
              next value unless type.is_a?(Schema::Base)

              case type.type
              when :hash
                next value unless value.is_a?(Hash)
                type.dataclass.unvalidated_new(**value)
              when :dictionary
                next value if type.scalar_classes.size != 1
                next value unless value.is_a?(Hash)

                type = type.scalar_classes.first
                value.map{ |k, v| [k, new_sub_dataclass(type, v)] }.to_h
              when :array
                next value if type.scalar_classes.size != 1
                next value unless value.is_a?(Array)

                type = type.scalar_classes.first
                value.map{ |v| new_sub_dataclass(type, v) }
              when :scalar
                value
              end
            end

            define_singleton_method(:unvalidated_new) do |value|
              schema.fields.each do |f|
                name = f.name

                # Prevent issue with optional fields
                # and required fields in Data structure
                if !value.key?(name)
                  value[name] = nil
                  next
                end

                value[name] = new_sub_dataclass(f.type, value[name])
              end

              bare_new.call(**value)
            end

            define_singleton_method(:new) do |*args, **hash|
              if args.size > 1
                raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 0..1)"
              end

              if args.size == 1 && !hash.empty?
                raise ArgumentError, "wrong number of arguments (given 1, expected 0 with hash)"
              end

              if args.size == 1
                hash = args.first
              end

              result = schema.validate(hash)

              unless result.success?
                raise InvalidSchemaError, result.errors
              end

              value = result.value

              unvalidated_new(value)
            end

            class_eval(&block) if block_given?
          end
        end
      end

      # Return a human-readable string representation of the schema.
      # The transformers and rules are not included in the output.
      def explain(indent: "", output: String.new)
        output << indent << "{\n"

        @fields.each do |field|
          field.explain(
            indent: "#{indent}  ",
            output:
          )
        end

        output << indent << "}\n"

        output
      end

      protected

      def validate_hash(input, error_builder, locals)
        unless input.is_a?(Hash)
          error_builder.add(nil, "must be a hash")
          return Result.new({}, error_builder.errors)
        end

        output = {}

        @fields.each do |field|
          key_s = field.key.to_s
          key_sym = key_s.to_sym

          exists = true
          value = input.fetch(key_s) { input.fetch(key_sym) { exists = false } }

          begin
            locals[:__path__].push(key_sym)

            if exists
              field.apply(value, output, error_builder, locals)
            elsif field.default?
              field.apply(field.default, output, error_builder, locals)
            elsif field.required?
              error_builder.add(field.key, "is required")
            end
          ensure
            # This is more performant than creating new array everytime,
            # but as in example, any storage of the array must be duplicated.
            locals[:__path__].pop
          end
        end

        if @extra_fields
          input.each do |key, value|
            output[key.to_sym] = value unless @fields.any? { |field| field.key.to_s == key.to_s }
          end
        end

        if @post_processors && error_builder.errors.empty?
          output = @post_processors.call(output, nil, error_builder, **locals)
        end

        Result.new(output, error_builder.errors)
      end

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
              @scalar_classes,
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

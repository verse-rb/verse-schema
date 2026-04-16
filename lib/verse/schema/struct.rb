# frozen_string_literal: true

require "stringio"

require_relative "./field"
require_relative "./result"
require_relative "./error_builder"
require_relative "./post_processor"
require_relative "./invalid_schema_error"

module Verse
  module Schema
    class Struct < Base
      CompiledContext = ::Struct.new(
        :input, :error_builder, :locals, :strict, :output
      )

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
        @cache_field_name = nil

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

      # rubocop:disable Style/OptionalBooleanParameter
      def extra_fields(value = true)
        @extra_fields = !!value
      end
      # rubocop:enable Style/OptionalBooleanParameter

      def extra_fields? = @extra_fields

      def valid?(input) = validate(input).success?

      def validate(input, error_builder: nil, locals: {}, strict: false)
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

        locals = { __path__: [] }.merge(locals) # Duplicate locals to prevent modification

        if frozen?
          validate_hash_compiled(input, error_builder, locals, strict)
        else
          validate_hash(input, error_builder, locals, strict)
        end
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
            Field.new(
              field.name,
              type.map do |t|
                next t unless t.is_a?(Base)

                t.respond_to?(:dataclass) ? t.dataclass : t.dataclass_schema
              end,
              field.opts.dup,
              post_processors: field.post_processors&.dup
            )
          elsif type.is_a?(Base)
            Field.new(
              field.name,
              type.respond_to?(:dataclass) ? type.dataclass : type.dataclass_schema,
              field.opts.dup,
              post_processors: field.post_processors&.dup
            )
          else
            field.dup
          end
        end

        @dataclass_schema.freeze
      end

      # Create a value object class from the schema.
      # Returns a Verse::Schema::Dataclass subclass with field accessors.
      #
      # @param block [Proc] Optional block evaluated in the context of the new class.
      # @return [Class<Verse::Schema::Dataclass>] The generated dataclass.
      def dataclass(&block)
        return @dataclass if @dataclass

        fields_list = @fields.map(&:name)
        fields_list << :extra_fields if extra_fields?

        # Create the class early so recursive schemas can reference it
        @dataclass = Class.new(Dataclass)

        # Build dataclass_schema (may recursively trigger nested dataclass creation)
        dc_schema = self.dataclass_schema

        # Special case for empty schema
        if fields_list.empty?
          @dataclass.class_eval do
            define_singleton_method(:schema) { dc_schema }
            define_singleton_method(:from_raw) { |_input = nil| allocate.freeze }

            define_singleton_method(:new) do |input = {}, validate: true|
              unless validate
                return from_raw(input)
              end

              result = dc_schema.validate(input)
              raise InvalidSchemaError, result.errors unless result.success?

              from_raw(result.value)
            end

            class_eval(&block) if block
          end

          return @dataclass
        end

        fields_frozen = fields_list.dup.freeze

        # Pre-compute ivar names to avoid repeated string interpolation
        ivar_map = fields_frozen.map { |f| [:"@#{f}", f] }.freeze
        has_extra_fields = extra_fields?

        @dataclass.class_eval do
          attr_reader(*fields_frozen)

          define_singleton_method(:members) { fields_frozen }
          define_singleton_method(:schema) { dc_schema }

          # Accept a plain Hash instead of **kwargs to avoid double hash allocation
          define_singleton_method(:from_raw) do |values_hash|
            instance = allocate
            ivar_map.each do |(ivar, fname)|
              instance.instance_variable_set(ivar, values_hash[fname])
            end
            instance.freeze
            instance
          end

          # Avoid *args (allocates Array) — use optional positional + **kwargs
          if has_extra_fields
            define_singleton_method(:new) do |input = Nothing, validate: true, **kwargs|
              if input.equal?(Nothing)
                input = kwargs
              elsif !kwargs.empty?
                raise ArgumentError, "You cannot pass both a hash and keyword arguments"
              end

              unless validate
                return from_raw(input)
              end

              result = dc_schema.validate(input)

              if result.success?
                value = result.value
                standard_fields = value.slice(*fields_frozen)
                extra = value.except(*fields_frozen)
                standard_fields[:extra_fields] = extra
                from_raw(standard_fields)
              else
                raise InvalidSchemaError, result.errors
              end
            end
          else
            define_singleton_method(:new) do |input = Nothing, validate: true, **kwargs|
              if input.equal?(Nothing)
                input = kwargs
              elsif !kwargs.empty?
                raise ArgumentError, "You cannot pass both a hash and keyword arguments"
              end

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
          end

          # Use instance_variable_get instead of send for better performance
          define_method(:to_h) do
            ivar_map.each_with_object({}) { |(ivar, fname), h| h[fname] = instance_variable_get(ivar) }
          end

          define_method(:==) do |other|
            return false unless other.is_a?(self.class)

            ivar_map.all? { |(ivar, _)| instance_variable_get(ivar) == other.instance_variable_get(ivar) }
          end
          alias_method :eql?, :==

          define_method(:hash) do
            [self.class, *ivar_map.map { |(ivar, _)| instance_variable_get(ivar) }].hash
          end

          define_method(:deconstruct_keys) do |keys|
            if keys.nil?
              to_h
            else
              keys.each_with_object({}) do |key, h|
                h[key] = instance_variable_get(:"@#{key}") if fields_frozen.include?(key)
              end
            end
          end

          define_method(:inspect) do
            pairs = ivar_map.map { |(ivar, fname)| "#{fname}: #{instance_variable_get(ivar).inspect}" }
            "#<data #{pairs.join(', ')}>"
          end
          alias_method :to_s, :inspect

          class_eval(&block) if block
        end

        @dataclass
      end

      def freeze
        return self if frozen?

        @cache_field_name = @fields.map(&:key).freeze

        compile_store = begin
          idx = 0

          proc do |value|
            var_name = "@_compiled_#{idx}"

            instance_variable_set(var_name, value)

            idx += 1
            var_name
          end
        end

        out = StringIO.new

        out.puts "def _validate_hash_compiled(input, error_builder, locals, strict, output)"

        @fields.each do |field|
          field.freeze

          key_sym = field.key
          key_sym_str = key_sym.inspect

          if (over = field.opts[:over])
            out.puts "  locals[:selector] = output[#{compile_store.(over)}]"
          end

          stored_field = compile_store.(field)
          if field.default?
            out.puts "  value = input.fetch(#{key_sym_str}){ #{stored_field}.default }"
            out.puts "  #{stored_field}.apply(value, output, error_builder, locals, strict)"
          elsif field.required?
            out.puts "  value = input.fetch(#{key_sym_str}, Nothing)"
            out.puts "  if value == Nothing"
            out.puts "    error_builder.add(#{key_sym_str}, \"is required\")"
            out.puts "  else"
            out.puts "    #{stored_field}.apply(value, output, error_builder, locals, strict)"
            out.puts "  end"

          else
            out.puts "  value = input.fetch(#{key_sym_str}, Nothing)"
            out.puts "  if value != Nothing"
            out.puts "    #{stored_field}.apply(value, output, error_builder, locals, strict)"
            out.puts "  end"
          end
        end

        if !@extra_fields
          out.puts "  if strict"
          out.puts "    extra_keys = input.keys - @cache_field_name"
          out.puts "    if extra_keys.any?"
          out.puts "      extra_keys.each do |key|"
          out.puts "        error_builder.add(key, \"is not allowed\")"
          out.puts "      end"
          out.puts "    end"
          out.puts "  end"
        end

        if @post_processors
          out.puts "  if error_builder.errors.empty?"
          out.puts "    output = @post_processors.call(output, nil, error_builder, **locals)"
          out.puts "  end"
        end

        out.puts "end"

        instance_eval(out.string)

        super
      end

      def inspect(visited=Set.new)
        if visited.include?(object_id)
          return "#<struct{...} 0x#{object_id.to_s(16)}>"
        end

        visited << object_id

        fields_string = @fields.map do |field|
          type_str = if field.type.is_a?(Array)
                       field.type.map{ |x|
                          if x.is_a?(Base)
                            x.inspect(visited)
                          else
                            x.inspect
                          end
                       }.join("|")
                     else
                       if field.type.is_a?(Base)
                          field.type.inspect(visited)
                        else
                         field.type.inspect
                        end
                     end

          optional_marker = field.optional? ? "?" : ""
          "#{field.name}#{optional_marker}: #{type_str}"
        end.join(", ")

        extra = @extra_fields ? ", ..." : ""

        "#<struct{#{fields_string}#{extra}} 0x#{object_id.to_s(16)}>"
      end

      protected

      def validate_hash_compiled(input, error_builder, locals, strict)
        input = input.transform_keys(&:to_sym)
        output = @extra_fields ? input : {}

        compiled_context = CompiledContext.new(input, error_builder, locals, strict, output)

        _validate_hash_compiled(input, error_builder, locals, strict, output)

        Result.new(compiled_context.output, compiled_context.error_builder.errors)
      end

      def validate_hash(input, error_builder, locals, strict)
        input = input.transform_keys(&:to_sym)
        output = @extra_fields ? input : {}

        @cache_field_name ||= @fields.map(&:key)

        @fields.each do |field|
          key_sym = field.key

          value = input.fetch(key_sym, Nothing)

          if (over = field.opts[:over])
            locals[:selector] = output[over]
          end

          if value != Nothing
            field.apply(value, output, error_builder, locals, strict)
          elsif field.default?
            field.apply(field.default, output, error_builder, locals, strict)
          elsif field.required?
            error_builder.add(field.key, "is required")
          end
        end

        # If strict mode is enabled, check for extra fields
        # that are not defined in the schema.
        if !@extra_fields && strict
          extra_keys = input.keys - @cache_field_name
          if extra_keys.any?
            extra_keys.each do |key|
              error_builder.add(key, "is not allowed")
            end
          end
        end

        if @post_processors && error_builder.errors.empty?
          output = @post_processors.call(output, nil, error_builder, **locals)
        end

        Result.new(output, error_builder.errors)
      end
    end
  end
end

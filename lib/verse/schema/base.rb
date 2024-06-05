# frozen_string_literal: true

require_relative "./field"
require_relative "./result"
require_relative "./error_builder"
require_relative "./post_processor"
require_relative "./invalid_schema_error"

module Verse
  module Schema
    class Base
      attr_reader :fields, :post_processors

      def initialize(fields: [], post_processors: IDENTITY_PP.dup, &block)
        @fields = fields
        @post_processors = post_processors
        instance_eval(&block) if block_given?
      end

      def rule(fields = nil, message = "rule failed", &block)
        @post_processors.attach(
          PostProcessor.new do |value, error|
            case block.arity
            when 1, -1, -2 # -1/-2 are for dealing with &:method block.
              error.add(fields, message) unless instance_exec(value, &block)
            when 2
              error.add(fields, message) unless instance_exec(value, error, &block)
            else
              raise ArgumentError, "invalid block arity"
            end

            value
          end
        )
      end

      def self.define(from = nil, &block)
        if from
          Base.new(
            fields: from.fields.map(&:dup),
            post_processors: from.post_processors.dup,
            &block
          )
        else
          Base.new(&block)
        end
      end

      def define(from = nil, &block)
        Verse::Schema::Base.define(from, &block)
      end

      def transform(&block)
        callback = proc do |value, error_builder|
          stop if error_builder.errors.any?
          instance_exec(value, error_builder, &block)
        end

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

        output = {}

        @fields.each do |field|
          exists = input.key?(field.key.to_s) || input.key?(field.key.to_sym)

          locals[:__path__] ||= []
          begin
            locals[:__path__].push(field.key)

            if exists
              value = input.fetch(field.key.to_s, input[field.key.to_sym])

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

        output = @post_processors.call(output, nil, error_builder, **locals) if error_builder.errors.empty?

        Result.new(output, error_builder.errors)
      end

      def dup
        Base.new(fields: @fields.map(&:dup), post_processors: @post_processors.dup)
      end

      def inherit?(parent_schema)
        parent_schema.is_a?(Base) && parent_schema.fields.all? { |parent_field|
          child_field = @fields.find { |f2| f2.name == parent_field.name }
          child_field&.inherit?(parent_field)
        }
      end

      alias_method :<, :inherit?

      def <=(other)
        other == self || inherit?(other)
      end

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

            field.post_processors.attach(f.post_processors)

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
        def dataclass
          schema = self

          @dataclass ||= Data.define(
            *fields.map(&:name)
          ) do
            previous_method = singleton_method(:new)

            define_singleton_method(:from_raw) do |hash|
              previous_method.call(**hash)
            end

            define_singleton_method(:new) do |*args, **hash|
              if args.size > 1
                raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 0..1)"
              end

              if args.size ==1 && !hash.empty?
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

              schema.fields.each do |f|
                data = value[f.name]

                next unless data

                if f.opts[:schema]
                  if data.is_a?(Hash)
                    value[f.name] = f.opts[:schema].dataclass.from_raw(data)
                  end
                elsif f.opts[:of] && f.opts[:of].is_a?(Base)
                  if f.type == Array
                    value[f.name] = data.map do |x|
                      if x.is_a?(Hash)
                        f.opts[:of].dataclass.from_raw(x)
                      else
                        x
                      end
                    end
                  elsif f.type == Hash
                    value[f.name] = data.transform_values do |v|
                      if v.is_a?(Hash)
                        f.opts[:of].dataclass.from_raw(v)
                      else
                        v
                      end
                    end
                  end
                end
              end

              previous_method.call(**value)
            end

          end
        end
      end
    end
  end
end

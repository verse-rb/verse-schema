# frozen_string_literal: true

module Verse
  module Schema
    module Coalescer
      Error = Class.new(StandardError)

      @mapping = {}
      @default_mapper_cache = {}

      DEFAULT_MAPPER = lambda do |type|
        if type.is_a?(Base)
          proc do |value, _opts, locals:, strict:|
            type.validate(value, locals:, strict:)
          end
        elsif type.is_a?(Class) && type < Dataclass
          schema = type.schema
          from_raw = type.method(:from_raw)
          proc do |value, _opts, locals:, strict:|
            # Already a dataclass instance of the right type — pass through
            next value if value.is_a?(type)

            result = schema.validate(value, locals:, strict:)

            if result.success?
              Result.new(from_raw.call(result.value), result.errors)
            else
              result
            end
          end
        elsif type.is_a?(Class) && type < ::Struct && type.keyword_init?
          proc do |value|
            type.new(**value)
          end
        elsif type.is_a?(Class)
          proc do |value|
            next value if value.is_a?(type)

            throw :fail, Error.new("invalid cast to `#{type}` for `#{value}`")
          end
        else
          proc do |value|
            throw :fail, Error.new("invalid cast to `#{type}` for `#{value}`")
          end
        end
      end

      class << self
        def register(*mapping, &block)
          mapping.each do |key|
            @mapping[key] = block
          end
        end

        # Lookup or lazily create & cache the mapper proc for a given type.
        # Avoids re-creating procs on every call to transform for non-registered types.
        def mapper_for(type)
          @mapping[type] || (@default_mapper_cache[type] ||= DEFAULT_MAPPER.call(type))
        end

        def transform(value, type, opts = {}, locals: {}, strict: false)
          if type.is_a?(Array)
            # fast-path for when the type match already
            type.each do |t|
              return value if t.is_a?(Class) && value.is_a?(t)
            end

            converted = nil

            last_error_message = nil

            found = false

            type.each do |t|
              converted = \
                catch(:fail) do
                  mapper_for(t).call(value, opts, locals:, strict:)
                end

              if converted.is_a?(StandardError)
                last_error_message = converted.message
                next
              end

              if !converted.is_a?(Result) ||
                 (converted.is_a?(Result) && converted.success?)
                found = true
                break
              end
            rescue StandardError => e
              last_error_message = e.message
              # next
            end

            return converted if found || converted.is_a?(Result)

            raise Error, (last_error_message || "invalid cast")
          else
            converted = catch(:fail) do
              mapper_for(type).call(value, opts, locals:, strict:)
            end

            return converted unless converted.is_a?(StandardError)

            raise Error, converted.message || "invalid cast to `#{type}` for `#{value}`"
          end
        end
      end
    end
  end
end

require_relative "./coalescer/register"

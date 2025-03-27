# frozen_string_literal: true

module Verse
  module Schema
    module Coalescer
      Error = Class.new(StandardError)

      @mapping = {}

      DEFAULT_MAPPER = lambda do |type|
        if type == Base
          proc do |value, opts, locals:|
            opts[:schema].validate(value, locals:)
          end
        elsif type.is_a?(Base)
          proc do |value, _opts, locals:|
            type.validate(value, locals:)
          end
        elsif type.is_a?(Class)
          proc do |value|
            next value if value.is_a?(type)

            raise Error, "invalid cast to `#{type}` for `#{value}`"
          end
        else
          proc do |value|
            raise Error, "invalid cast to `#{type}` for `#{value}`"
          end
        end
      end

      class << self
        def register(*mapping, &block)
          mapping.each do |key|
            @mapping[key] = block
          end
        end

        def transform(value, type, opts = {}, locals: {})
          # Cache the mapper for each type to avoid repeated lookups
          @mapper_cache ||= {}

          if type.is_a?(Array)
            converted = nil
            last_error_message = nil
            found = false

            type.each do |t|
              # Use cached mapper if available
              mapper = @mapper_cache[t] ||= @mapping.fetch(t) { DEFAULT_MAPPER.call(t) }

              begin
                converted = mapper.call(value, opts, locals: locals)

                # Fast path check for success
                if !converted.is_a?(Result) || (converted.is_a?(Result) && converted.success?)
                  found = true
                  break
                end
              rescue StandardError => e
                last_error_message = e.message
              end
            end

            return converted if found || converted.is_a?(Result)
            raise Error, (last_error_message || "invalid cast")
          else
            # Use cached mapper if available
            mapper = @mapper_cache[type] ||= @mapping.fetch(type) { DEFAULT_MAPPER.call(type) }
            mapper.call(value, opts, locals: locals)
          end
        end
      end
    end
  end
end

require_relative "./coalescer/register"

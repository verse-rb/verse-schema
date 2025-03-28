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
          if type.is_a?(Array)
            converted = nil

            last_error_message = nil

            found = false
            type.each do |t|
              converted = @mapping.fetch(t) do
                DEFAULT_MAPPER.call(t)
              end.call(value, opts, locals:)

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
            @mapping.fetch(type) do
              DEFAULT_MAPPER.call(type)
            end.call(value, opts, locals:)
          end
        end
      end
    end
  end
end

require_relative "./coalescer/register"

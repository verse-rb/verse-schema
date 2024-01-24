# frozen_string_literal: true

module Verse
  module Schema
    module Coalescer
      Error = Class.new(StandardError)

      @mapping = {}

      DEFAULT_MAPPER = lambda do |type|
        case type
        when Base
          proc do |value, _opts|
            raise Error, "hash expected" unless value.is_a?(Hash)

            type.validate(value)
          end
        when Class
          proc do |value, _opts, _key, _error|
            next value if value.is_a?(type)

            raise Error, "Invalid cast to `#{type}` for `#{value}`"
          end
        else
          proc do |value, _opts, _key, _error|
            raise Error, "Invalid cast to `#{type}` for `#{value}`"
          end
        end
      end

      class << self
        def register(*mapping, &block)
          mapping.each do |key|
            @mapping[key] = block
          end
        end

        def transform(value, type, opts = {})
          if type.is_a?(Array)
            has_result = false
            converted = nil

            type.each do |t|
              converted = @mapping.fetch(t) do
                  DEFAULT_MAPPER.call(t)
                end.call(value, opts)

              if !converted.is_a?(Result) ||
                (converted.is_a?(Result) && converted.success?)
                has_result = true
                break
              end

            rescue StandardError
              # next
            end

            return converted if has_result || converted.is_a?(Result)

            raise Error, "Invalid cast to `#{type}` for `#{value}`"
          else
            @mapping.fetch(type) do
              DEFAULT_MAPPER.call(type)
            end.call(value, opts)
          end
        end
      end
    end
  end
end

require_relative "./coalescer/register"

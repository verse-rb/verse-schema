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
            if value.is_a?(Hash)
              type.validate(value)
            else
              raise Error, "hash expected"
            end
          end
        when Class
          proc do |value, _opts, key, error|
            return value if value.is_a?(type)

            raise Error, "Invalid cast to `#{type}` for `#{value}`"
          end
        else
          proc do |value, _opts, key, error|
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

        def transform(value, type, opts={})
          if type.is_a?(Array)
            has_result = false
            converted = nil

            type.each do |t|
              catch(:next) do
                converted = @mapping.fetch(t) { throw(:next) }.call(value, opts)
                has_result = true
                break
              end
            rescue Error
              next
            end

            return converted if has_result

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

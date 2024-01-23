# frozen_string_literal: true

module Verse
  module Schema
    module Coalescer
      Error = Class.new(StandardError)

      @mapping = {}

      DEFAULT_MAPPER = lambda do |type|
        lambda do |value, _opts|
          return value if type.is_a?(Class) && value.is_a?(type)

          raise Error, "Invalid cast to `#{type}` for `#{value}`"
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

# frozen_string_literal: true

require "date"
require "time"

module Verse
  module Schema
    module Coalescer
      register(String) do |value, _opts|
        value.to_s
      end

      register(Integer) do |value, _opts|
        Integer(value)
      rescue StandardError
        raise Coalescer::Error, "Invalid integer `#{value}`"
      end

      register(Float) do |value, _opts|
        Float(value)
      rescue StandardError
        raise Coalescer::Error, "Invalid float `#{value}`"
      end

      register(Symbol) do |value, _opts|
        x = value.to_s
        raise Coalescer::Error, "Invalid symbol `#{x}`" if x.empty?

        x.to_sym
      end

      register(Time) do |value, _opts|
        case value
        when Time
          value
        when String
          Time.parse(value)
        else
          raise Coalescer::Error, "Invalid time `#{value}`"
        end
      rescue StandardError
        raise Coalescer::Error, "Invalid time `#{value}`"
      end

      register(Date) do |value, _opts|
        case value
        when Date
          value
        when String
          Date.parse(value)
        else
          raise Coalescer::Error, "Invalid date `#{value}`"
        end
      rescue StandardError
        raise Coalescer::Error, "Invalid date `#{value}`"
      end

      register(Hash) do |value, opts|
        case value
        when Hash
          case
          when opts[:block]
            schema = Verse::Schema.define(&opts[:block])
            schema.validate(value)
          when opts[:as]
            opts[:as].validate(value)
          when opts[:of]
            # open hash with validation on keys:
            error_builder = Verse::Schema::ErrorBuilder.new

            output = value.inject({}) do |(k, v), h|
              field = Coalescer.transform(k, opts[:of], {})

              if field.is_a?(Result)
                error_builder.combine(k, field.errors)
                h[k] = field.value
              end

            rescue Coalescer::Error => e
              error_builder.add(k, e.message)
            end

            Result.new(output, error_builder.errors)
          else
            # open hash
            next value
          end
        else
          raise Coalescer::Error, "Invalid hash `#{value}`"
        end
      rescue StandardError
        raise Coalescer::Error, "Invalid hash `#{value}`"
      end

      register(Array) do |value, opts|
        case value
        when Array
          type = nil

          if opts[:block]
            schema = Verse::Schema.define(&opts[:block])
          end

          if opts[:of]
            schema = opts[:of]
          end

          if schema.nil?
            next value # open array.
          end

          error_builder = Verse::Schema::ErrorBuilder.new

          output = value.map.with_index do |v, idx|
            field = Coalescer.transform(v, schema, {})

            if field.is_a?(Result)
              error_builder.combine(idx, field.errors)
              field.value
            else
              field
            end
          rescue Coalescer::Error => e
            error_builder.add(idx, e.message)
          end

          Result.new(output, error_builder.errors)
        else
          raise Coalescer::Error, "Invalid array `#{value}`"
        end
      end

      register(nil) do |value, _opts|
        next nil if value.nil? || value == ""

        raise Coalescer::Error, "Invalid `#{value}`"
      end

      register(TrueClass, true, false) do |value, _opts|
        case value
        when TrueClass, FalseClass
          value
        when String
          %w[t y true yes].include?(value)
        when Numeric
          value != 0
        else
          raise Coalescer::Error, "Invalid boolean `#{value}`"
        end
      end
    end
  end
end

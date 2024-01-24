# frozen_string_literal: true

require "date"
require "time"

module Verse
  module Schema
    module Coalescer
      register(String) do |value, _opts|
        case value
        when String
          value
        when Numeric
          value.to_s
        else
          raise Coalescer::Error, "must be a string"
        end
      end

      register(Integer) do |value, _opts|
        Integer(value)
      rescue StandardError
        raise Coalescer::Error, "must be an integer"
      end

      register(Float) do |value, _opts|
        Float(value)
      rescue StandardError
        raise Coalescer::Error, "must be a float"
      end

      register(Symbol) do |value, _opts|
        case value
        when Symbol
          next value
        when Numeric
          value.to_s.to_sym
        when String
          raise Coalescer::Error, "must be a symbol" if value.empty?
          value.to_sym
        else
          raise Coalescer::Error, "must be a symbol"
        end
      end

      register(Time) do |value, _opts|
        case value
        when Time
          value
        when String
          Time.parse(value)
        else
          raise Coalescer::Error, "must be a datetime"
        end
      rescue StandardError
        raise Coalescer::Error, "must be a datetime"
      end

      register(Date) do |value, _opts|
        case value
        when Date
          value
        when String
          Date.parse(value)
        else
          raise Coalescer::Error, "must be a date"
        end
      rescue StandardError
        raise Coalescer::Error, "must be a date"
      end

      register(Hash) do |value, opts|
        case value
        when Hash
          if opts[:block]
            schema = Verse::Schema.define(&opts[:block])
            schema.validate(value)
          elsif opts[:as]
            opts[:as].validate(value)
          elsif opts[:of]
            # open hash with validation on keys:
            error_builder = Verse::Schema::ErrorBuilder.new

            output = value.inject({}) do |h, (k,v)|
              begin
                field = Coalescer.transform(v, opts[:of])

                if field.is_a?(Result)
                  error_builder.combine(k, field.errors)
                  h[k.to_sym] = field.value
                else
                  h[k.to_sym] = field
                end

                h
              rescue Coalescer::Error => e
                error_builder.add(k, e.message)
                h
              end

            end

            Result.new(output, error_builder.errors)
          else
            # open hash
            next value
          end
        else
          raise Coalescer::Error, "must be a hash"
        end
      rescue StandardError
        raise Coalescer::Error, "must be a hash"
      end

      register(Array) do |value, opts|
        case value
        when Array

          schema = Verse::Schema.define(&opts[:block]) if opts[:block]

          schema = opts[:of] if opts[:of]

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
          raise Coalescer::Error, "must be a array"
        end
      end

      register(nil, NilClass) do |value, _opts|
        next nil if value.nil? || value == ""

        raise Coalescer::Error, "must be nil"
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
          raise Coalescer::Error, "must be a boolean"
        end
      end
    end
  end
end

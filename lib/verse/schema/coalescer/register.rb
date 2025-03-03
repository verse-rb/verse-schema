# frozen_string_literal: true

require "date"
require "time"

module Verse
  module Schema
    module Coalescer
      register(String) do |value|
        case value
        when String
          value
        when Numeric
          value.to_s
        else
          raise Coalescer::Error, "must be a string"
        end
      end

      register(Integer) do |value|
        Integer(value)
      rescue TypeError, ArgumentError
        raise Coalescer::Error, "must be an integer"
      end

      register(Float) do |value|
        Float(value)
      rescue TypeError, ArgumentError
        raise Coalescer::Error, "must be a float"
      end

      register(Symbol) do |value|
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

      register(Time) do |value|
        case value
        when Time
          value
        when String
          Time.parse(value)
        else
          raise Coalescer::Error, "must be a datetime"
        end
      rescue ArgumentError
        raise Coalescer::Error, "must be a datetime"
      end

      register(Date) do |value|
        case value
        when Date
          value
        when String
          Date.parse(value)
        else
          raise Coalescer::Error, "must be a date"
        end
      rescue Date::Error
        raise Coalescer::Error, "must be a date"
      end

      register(Hash) do |value, opts, locals:|
        raise Coalescer::Error, "must be a hash" unless value.is_a?(Hash)

        if opts[:schema]
          opts[:schema].validate(value, locals:)
        elsif opts[:of]
          # open hash with validation on keys:
          error_builder = Verse::Schema::ErrorBuilder.new

          output = value.inject({}) do |h, (k, v)|
            locals[:__path__] ||= []
            begin
              k = k.to_sym
              locals[:__path__].push(k)

              field = Coalescer.transform(v, opts[:of], locals:)

              if field.is_a?(Result)
                error_builder.combine(k, field.errors)
                h[k] = field.value
              else
                h[k] = field
              end
            ensure
              locals[:__path__].pop
            end

            h
          rescue Coalescer::Error => e
            error_builder.add(k, e.message)
            h
          end

          Result.new(output, error_builder.errors)
        else
          # open hash, deep symbolize keys
          deep_symbolize_keys = ->(value) do
            case value
            when Array
              value.map{ |x| deep_symbolize_keys.call(x) }
            when Hash
              value.map do |k, v|
                [k.to_sym, deep_symbolize_keys.call(v)]
              end.to_h
            else
              value
            end
          end

          next deep_symbolize_keys.call(value)
        end
      end

      register(Array) do |value, opts, locals:|
        case value
        when Array
          if opts[:of].nil?
            next value # open array.
          end

          error_builder = Verse::Schema::ErrorBuilder.new

          output = value.map.with_index do |v, idx|
            locals[:__path__] ||= []
            begin
              locals[:__path__].push(idx)

              field = Coalescer.transform(v, opts[:of], {})

              if field.is_a?(Result)
                error_builder.combine(idx, field.errors)
                field.value
              else
                field
              end
            ensure
              locals[:__path__].pop
            end
          rescue Coalescer::Error => e
            error_builder.add(idx, e.message)
          end

          Result.new(output, error_builder.errors)
        else
          raise Coalescer::Error, "must be a array"
        end
      end

      register(nil, NilClass) do |value|
        next nil if value.nil? || value == ""

        raise Coalescer::Error, "must be nil"
      end

      register(TrueClass, FalseClass, true, false) do |value|
        case value
        when TrueClass, FalseClass
          value
        when String
          next true if %w[t y true yes].include?(value)
          next false if %[f n false no].include?(value)

          raise Coalescer::Error, "must be a boolean"
        when Numeric
          value != 0
        else
          raise Coalescer::Error, "must be a boolean"
        end
      end
    end
  end
end

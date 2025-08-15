# frozen_string_literal: true

require "date"
require "time"

module Verse
  module Schema
    module Coalescer
      # open hash, deep symbolize keys
      def self.deep_symbolize_keys(value)
        case value
        when Array
          value.map{ |x| deep_symbolize_keys(x) }
        when Hash
          value.map do |k, v|
            [k.to_sym, deep_symbolize_keys(v)]
          end.to_h
        else
          value
        end
      end

      register(String) do |value|
        case value
        when String
          value
        when Numeric
          value.to_s
        else
          throw :fail, Coalescer::Error.new("must be a string")
        end
      end

      register(Integer) do |value|
        Integer(value)
      rescue TypeError, ArgumentError
        throw :fail, Coalescer::Error.new("must be an integer")
      end

      register(Float) do |value|
        Float(value)
      rescue TypeError, ArgumentError
        throw :fail, Coalescer::Error.new("must be a float")
      end

      register(Symbol) do |value|
        case value
        when Symbol
          next value
        when Numeric
          value.to_s.to_sym
        when String
          throw :fail, Coalescer::Error.new("must be a symbol") if value.empty?

          value.to_sym
        else
          throw :fail, Coalescer::Error.new("must be a symbol")
        end
      end

      register(Time) do |value|
        case value
        when Time
          value
        when String
          # Optimization: Try specific format first, fallback to general parse
          begin
            # Attempt fast parsing with the common format used in JSON
            format = "%Y-%m-%d %H:%M:%S"
            Time.strptime(value, format)
          rescue ArgumentError # Raised by strptime on format mismatch
            # Fallback to slower, more general parsing if strptime failed
            Time.parse(value)
          end
        else
          throw :fail, Coalescer::Error.new("must be a datetime")
        end
      rescue ArgumentError
        throw :fail, Coalescer::Error.new("must be a datetime")
      end

      register(Date) do |value|
        case value
        when Date
          value
        when String
          Date.parse(value)
        else
          throw :fail, Coalescer::Error.new("must be a date")
        end
      rescue Date::Error
        throw :fail, Coalescer::Error.new("must be a date")
      end

      register(Hash) do |value|
        # Open hash without contract.

        throw :fail, Coalescer::Error.new("must be a hash") unless value.is_a?(Hash)

        Coalescer.deep_symbolize_keys(value)
      end

      register(Array) do |value|
        throw :fail, Coalescer::Error.new("must be an array") unless value.is_a?(Array)

        value
      end

      register(nil, NilClass) do |value|
        next nil if value.nil? || value == "" || value == "null" # json handling

        throw :fail, Coalescer::Error.new("must be nil")
      end

      register(TrueClass, FalseClass, true, false) do |value|
        case value
        when TrueClass, FalseClass
          value
        when String
          next true if %w[t y true yes].include?(value)
          next false if %w[f n false no].include?(value)

          throw :fail, Coalescer::Error.new("must be a boolean")
        when Numeric
          value != 0
        else
          throw :fail, Coalescer::Error.new("must be a boolean")
        end
      end
    end
  end
end

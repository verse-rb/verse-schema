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

      # Pre-compiled regex patterns for fast Time parsing
      ISO_DATETIME_REGEX = /\A(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?(?:Z|([+-]\d{2}):?(\d{2}))?\z/.freeze

      register(Time) do |value|
        case value
        when Time
          value
        when String
          # Fast path
          if (m = ISO_DATETIME_REGEX.match(value))
            year, month, day = m[1].to_i, m[2].to_i, m[3].to_i
            hour, min, sec = m[4].to_i, m[5].to_i, m[6].to_i

            if m[8] # timezone offset present
              offset_hours = m[8].to_i
              offset_mins = m[9].to_i
              offset_sec = (offset_hours * 3600) + (offset_mins * 60)
              offset_sec = -offset_sec if offset_hours < 0 || (offset_hours == 0 && m[8].start_with?("-"))
              Time.new(year, month, day, hour, min, sec, offset_sec)
            elsif m[7] # sub-second present
              Time.new(year, month, day, hour, min, sec)
            else
              Time.new(year, month, day, hour, min, sec)
            end
          else
            # Fallback
            Time.parse(value)
          end
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

      register(Hash) do |value|
        # Open hash without contract.

        raise Coalescer::Error, "must be a hash" unless value.is_a?(Hash)

        Coalescer.deep_symbolize_keys(value)
      end

      register(Array) do |value|
        raise Coalescer::Error, "must be an array" unless value.is_a?(Array)

        value
      end

      register(nil, NilClass) do |value|
        next nil if value.nil? || value == "" || value == "null"

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

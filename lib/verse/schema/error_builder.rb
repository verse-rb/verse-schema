# frozen_string_literal: true

module Verse
  module Schema
    class ErrorBuilder
      attr_reader :errors, :root

      def initialize(root = nil, errors = {})
        @errors = errors
        @root = root
      end

      def context(key_name)
        new_root = [@root, key_name].compact.join(".")
        yield(
          ErrorBuilder.new(new_root, @errors)
        )
      end

      def combine(key, errors)
        errors.each do |k, v|
          real_key = [@root, key, k].compact.join(".").to_sym
          (@errors[real_key] ||= []).concat(v)
        end
      end

      def add(keys, message = "validation_failed")
        case keys
        when Array
          keys.each { |key| add(key, message) }
        else
          real_key = [@root, keys].compact.join(".").to_sym
          (@errors[real_key] ||= []) << message
        end
      end
    end
  end
end

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

      def add(key, message = "validation_failed")
        real_key = [@root, key].compact.join(".").to_sym
        (@errors[real_key] ||= []) << message
      end
    end
  end
end
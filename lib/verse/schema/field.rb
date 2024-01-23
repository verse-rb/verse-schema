# frozen_string_literal: true

require_relative "./optionable"
require_relative "./coalescer"

module Verse
  module Schema
    class Field
      include Optionable

      attr_reader :name, :type

      def initialize(name, type, opts, &block)
        @name = name
        @type = type
        @opts = opts

        return unless block_given?

        @opts[:block] = block
      end

      option :label, default: -> { @name }
      option :key, default: -> { @name }
      option :description, default: -> { nil }

      def optional
        @opts[:optional] = true

        self
      end

      def required
        @opts[:optional] = false

        self
      end

      def required?
        !@opts[:optional]
      end

      def optional?
        !required?
      end

      def rule(rule, &block)
        case rule
        when String
          @rules ||= []
          @rules << Rule.new(rule, block)

          self
        when Rule
          @rules ||= []
          @rules << rule

          self
        end
      end

      def apply(value, output, errors)
        if @type.is_a?(Base)
          if value.is_a?(Hash)
            errors.context(@name) do |error_builder|
              result = @type.validate(value, error_builder)
              output[@name] = result.value
            end
          else
            errors.add(@name, "hash expected")
          end
        else
          transformed_value = (
            output[@name] = Coalescer.transform(value, @type, @opts)
          )

          @rules&.each do |rule|
            unless rule.call(transformed_value, output)
              errors.add(@name, rule.message)
            end
          end
        end
      rescue Coalescer::Error => e
        errors.add(@name, e.message)
      end

    end
  end
end

require_relative "./field/ext"
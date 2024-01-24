# frozen_string_literal: true

require_relative "./optionable"
require_relative "./coalescer"
require_relative "./post_processor"

module Verse
  module Schema
    class Field
      include Optionable

      attr_reader :name, :type

      def initialize(name, type, opts, &block)
        @name = name
        @type = type
        @opts = opts
        # Setup identity processor
        @post_processors = IDENTITY_PP.dup

        return unless block_given?

        @opts[:block] = block
      end

      option :label, default: -> { @name }
      option :key, default: -> { @name }
      option :description, default: -> { nil }
      option :type

      def optional
        @opts[:optional] = true

        self
      end

      def default(value = Optionable::NOTHING, &block)
        if value == Optionable::NOTHING && !block_given?
          if @default.is_a?(Proc)
            @default.call
          else
            @default
          end
        else
          @default = block || value
          @has_default = true
          optional
        end
      end

      def default?
        !!@has_default
      end

      def required
        @opts[:optional] = false
        @has_default = false

        self
      end

      def required?
        !@opts[:optional]
      end

      def optional?
        !required?
      end

      def rule(rule, &block)
        rule_processor = \
          case rule
          when String
            PostProcessor.new do |value, error|
              error.call(rule) unless block.call(value, error)
              value
            end
          when PostProcessor
            rule
          else
            raise ArgumentError, "invalid rule type #{rule}"
          end

        @post_processors.attach(rule_processor)

        self
      end

      def transform(&block)
        @post_processors.attach(
          PostProcessor.new(&block)
        )
      end

      def apply(value, output, error_builder)
        if @type.is_a?(Base)
          if value.is_a?(Hash)
            error_builder.context(@name) do |error_builder|
              result = @type.validate(value, error_builder)
              output[@name] = result.value
            end
          else
            error_builder.add(@name, "hash expected")
          end
        else
          coalesced_value =
            Coalescer.transform(value, @type, @opts)

          if coalesced_value.is_a?(Result)
            error_builder.combine(@name, coalesced_value.errors)
            coalesced_value = coalesced_value.value
          end

          output[@name] = @post_processors.call(
            coalesced_value, @name, error_builder
          )

        end
      rescue Coalescer::Error => e
        error_builder.add(@name, e.message)
      end
    end
  end
end

require_relative "./field/ext"

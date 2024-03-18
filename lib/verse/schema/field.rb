# frozen_string_literal: true

require_relative "./optionable"
require_relative "./coalescer"
require_relative "./post_processor"

module Verse
  module Schema
    # A field in a schema
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

        @opts[:block] = Schema.define(&block)
      end

      option :key, default: -> { @name }
      option :type

      def optional
        @opts[:optional] = true

        self
      end

      # Add metadata to the field. Useful for documentation
      # purpose
      # @param [Hash] opts the fields to add to the meta hash
      # @return [self]
      # @example
      #
      #   field(:name, String).meta(description: "The name of the user")
      #
      def meta(**opts)
        @opts[:meta] ||= {}
        @opts[:meta].merge!(opts)

        self
      end

      # Set the default value for the field
      #
      # Please note that the default value is applied BEFORE any post processor
      # such as `transform` or `rule` are ran.
      #
      # For example, if you have this:
      #
      #   field(:age, Integer).default(17).rule("must be greater than 18") { |v| v > 18 }
      #
      # This will fail if the field is not present, because the default value
      # is applied before the rule is ran.
      #
      # @param [Object] value the default value
      # @param [Proc] block the block to call to get the default value, if any.
      # @return [self]
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

      # Mark the field as required
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

      # Add a rule to the field. A rule is a block that will be called
      # with the value of the field. If the block returns false, an error
      # will be added to the error builder.
      #
      # `rule` and `transform` can be chained together to add multiple rules.
      # They are called in the order they are added.
      #
      # @param [String] error message if the rule is failing
      # @param [Proc] block the block to call to validate the value
      # @return [self]
      def rule(rule, &block)
        rule_processor = \
          case rule
          when String
            PostProcessor.new(key: key) do |value, error|
              case block.arity
              when 1, -1, -2 # -1/-2 are for dealing with &:method block.
                error.add(opts[:key], rule) unless block.call(value)
              when 2
                error.add(opts[:key], rule) unless block.call(value, error)
              else
                raise ArgumentError, "invalid block arity"
              end

              value
            end
          when PostProcessor
            rule.opts[:key] = key
            rule
          else
            raise ArgumentError, "invalid rule type #{rule}"
          end

        @post_processors.attach(rule_processor)

        self
      end

      # Add a transformation to the field. A transformation is a block that
      # will be called with the value of the field. The return value of the
      # block will be the new value of the field.
      #
      # If the block raises an error, the error will be added to the error
      # builder.
      def transform(&block)
        callback = proc do |value, error_builder|
          stop if error_builder.errors.any?
          block.call(value, error_builder)
        end

        @post_processors.attach(
          PostProcessor.new(&callback)
        )
      end

      # :nodoc:
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

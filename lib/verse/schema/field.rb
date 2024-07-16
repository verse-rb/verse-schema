# frozen_string_literal: true
# encoding: utf-8

require_relative "./optionable"
require_relative "./coalescer"
require_relative "./post_processor"

module Verse
  module Schema
    # A field in a schema
    class Field
      include Optionable

      attr_reader :name, :type, :opts, :post_processors

      def initialize(name, type, opts, post_processors: IDENTITY_PP.dup, &block)
        @name = name
        @opts = opts
        # Setup identity processor
        @post_processors = post_processors

        if type.is_a?(Schema::Base)
          @type = Hash
          @opts[:schema] = type
        else
          @type = type
        end

        if block_given?
          if @opts[:of]
            raise ArgumentError, "cannot pass `of` and a block at the same time"
          end

          if @opts[:schema]
            raise ArgumentError, "cannot pass `schema` and a block at the same time"
          end

          if [Hash, Object].include?(type) # Object when type is ommited.
            @type = Hash
            @opts[:schema] = Schema.define(&block)
          elsif type == Array
            @opts[:of] = Schema.define(&block)
          else
            raise ArgumentError, "block is only allowed with Hash or Array type"
          end
        end

        return if [Hash, Array].include?(@type)
        if @opts[:of]
          raise ArgumentError, "use `of` only with Array or Hash type but `#{@type}` given"
        end

        return unless @opts[:schema]

        raise ArgumentError, "use `of` only with Array or Hash type but `#{@type}` given"
      end

      option :key, default: -> { @name }
      option :type

      def optional
        @opts[:optional] = true

        self
      end

      def dup
        Field.new(
          @name,
          @type,
          @opts.dup,
          post_processors: @post_processors.dup
        )
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

      # Check if the field has a default value
      # @return [Boolean] true if the field has a default value
      def default?
        !!@has_default
      end

      # Mark the field as required. This will make the field mandatory.
      # Remove any default value.
      # @return [self]
      def required
        @opts[:optional] = false
        @has_default = false

        self
      end

      # Check if the field is required
      # @return [Boolean] true if the field is required
      def required?
        !@opts[:optional]
      end

      # Check if the field is optional
      # @return [Boolean] true if the field is optional
      def optional?
        !!@opts[:optional]
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
            PostProcessor.new(key:) do |value, error|
              case block.arity
              when 1, -1, -2 # -1/-2 are for dealing with &:method block.
                error.add(opts[:key], rule, **locals) unless instance_exec(value, &block)
              when 2
                error.add(opts[:key], rule, **locals) unless instance_exec(value, error, &block)
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
      #
      # @param [Proc] block the block to call to transform the value
      # @return [self]
      def transform(&block)
        callback = proc do |value, error_builder|
          stop if error_builder.errors.any?
          instance_exec(value, error_builder, &block)
        end

        @post_processors.attach(
          PostProcessor.new(&callback)
        )

        self
      end

      # Check whether the field is matching the condition of the parent field.
      def inherit?(parent_field)
        case @type
        when Array
          # @type must be a superset of parent.
          # not easy to do, FIXME
          raise NotImplementedError, "inheritance check with multiple type field not supported yet."
        else
          # wrong type
          return false unless @type <= parent_field.type

          if parent_field.opts[:schema]
            @type == Hash &&
              (
                !@opts[:schema] ||
                @opts[:schema] <= parent_field.opts[:schema]
              )
          elsif parent_field.opts[:of]
            # Open array / dictionary OR the type of `of` inherit of
            # the parent.
            !@opts[:of] || @opts[:of] <= parent_field.opts[:of]
          else
            true
          end
        end
      end

      def <=(parent_field)
        (
          parent_field.type == self.type &&
          parent_field.opts[:schema] == self.opts[:schema] &&
          parent_field.opts[:of] == self.opts[:of]
        ) || inherit?(parent_field)
      end

      alias_method :<, :inherit?

      private def explain_type(type, indent:, output:)
        if type == Hash
          if opts[:schema]
            opts[:schema].explain(indent: indent + "  ", output:)
            output << "#{indent}"
          elsif opts[:of] && opts[:of] != Object
            output << "Dictionary<Symbol,\n"
            explain_type(opts[:of], indent: indent + "  ", output:)
            output << "#{indent}>"
          else
            output << "Hash"
          end
        elsif type == Array
          if opts[:of] && opts[:of] != Object
            output << "Array<\n"
            explain_type(opts[:of], indent: indent + "  ", output:)
            output << "#{indent}>"
          else
            output << "Array"
          end
        elsif type.is_a?(Base)
          type.explain(indent: indent + "  ", output:)
        elsif type.is_a?(Array)
          output << "Union<\n"
          type.each_with_index do |t, idx|
            output << "#{indent},\n" unless idx == 0
            explain_type(t, indent: indent + "  ", output: output)
          end
          output << "#{indent}>"

        else
          output << "#{indent}#{type}\n"
        end
      end

      def explain(indent: "", output: String.new)
        default = @has_default ? " = #{default}" : ""
        optional = @opts[:optional] ? "?" : ""

        output << "#{indent}#{name}#{optional} : "
        explain_type(type, indent: indent, output: output)
        output << "#{default}\n"

        output
      end

      # :nodoc:
      def apply(value, output, error_builder, locals)
        if @type.is_a?(Base)
          if value.is_a?(Hash)
            error_builder.context(@name) do |error_builder|
              result = @type.validate(value, error_builder:, locals:)
              output[@name] = result.value
            end
          else
            error_builder.add(@name, "hash expected")
          end
        else
          coalesced_value =
            Coalescer.transform(value, @type, @opts, locals:)

          if coalesced_value.is_a?(Result)
            error_builder.combine(@name, coalesced_value.errors)
            coalesced_value = coalesced_value.value
          end

          output[@name] = @post_processors.call(
            coalesced_value, @name, error_builder, **locals
          )

        end
      rescue Coalescer::Error => e
        error_builder.add(@name, e.message, **locals)
      end
    end
  end
end

require_relative "./field/ext"

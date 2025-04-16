# frozen_string_literal: true

require "attr_chainable"
require_relative "./coalescer"
require_relative "./post_processor"

module Verse
  module Schema
    # A field in a schema
    class Field
      attr_reader :opts, :post_processors, :name, :type

      def initialize(name, type, opts, post_processors: nil, &block)
        @name = name
        @opts = opts
        # Setup identity processor
        @post_processors = post_processors

        of_arg = opts[:of] # For array and dictionary
        of_arg = [of_arg] unless of_arg.nil? || of_arg.is_a?(Array)

        nested_schema = nil

        if block_given?
          if of_arg
            raise ArgumentError, "cannot pass `of` and a block at the same time"
          end

          if type != Hash && type != Object && type != Array
            raise ArgumentError, "block can only be used with Hash, Object or Array type"
          end

          nested_schema = Schema.define(&block)

          if type == Array
            self.type(
              Schema.array(nested_schema)
            )
          else
            self.type(nested_schema)
          end
        else
          self.type(type)
        end
      end

      def type(type = Nothing, of: Nothing, over: Nothing)
        return @type if type == Nothing

        @opts[:of] = of if of != Nothing
        @opts[:over] = over if over != Nothing

        of_arg = @opts[:of] # For array and dictionary
        of_arg = [of_arg] unless of_arg.nil? || of_arg.is_a?(Array)

        if type == Hash || type == Object
          type = Schema.dictionary(*of_arg) if of_arg # dictionary
        elsif type == Array
          type = Schema.array(*of_arg) if of_arg
        elsif type.is_a?(Hash) # Selector structure
          @opts[:over] => Symbol # Ensure there is an over field

          type = Schema.selector(**type)
        end

        @type = type

        self
      end

      # Set the field as optional. This will validate schema where the
      # field key is missing.
      #
      # Note: If the key is nil, the field will be considered as
      # existing, and your schema might fail. To allow field to be nil,
      # you must use union of type:
      #
      #  field(:name, [String, NilClass]).optional
      #
      # This will allow the field to be nil, and will not raise an error
      # if the field is missing.
      #
      # @return [self]
      def optional
        @opts[:optional] = true

        self
      end

      def key(value = Nothing)
        if value == Nothing
          @opts[:key] ||= @name
        else
          @opts[:key] = value
          self
        end
      end

      def dup
        Field.new(
          @name,
          @type,
          @opts.dup,
          post_processors: @post_processors&.dup
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
      def default(value = Nothing, &block)
        if value == Nothing && !block_given?
          if @opts[:default].is_a?(Proc)
            @opts[:default].call
          else
            @opts[:default]
          end
        else
          @opts[:default] = block || value
          optional
        end
      end

      # Check if the field has a default value
      # @return [Boolean] true if the field has a default value
      def default?
        @opts.key?(:default)
      end

      # Mark the field as required. This will make the field mandatory.
      # Remove any default value.
      # @return [self]
      def required
        @opts[:optional] = false
        @opts.delete(:default)

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

      def array?
        @type == Array || ( @type.is_a?(Schema::Base) && @type.type == :array )
      end

      def dictionary?
        @type.is_a?(Schema::Base) && @type.type == :dictionary
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
                # :nocov:
                raise ArgumentError, "invalid block arity"
                # :nocov:
              end

              value
            end
          when PostProcessor
            rule.opts[:key] = key
            rule.dup
          else
            # :nocov:
            raise ArgumentError, "invalid rule type #{rule}"
            # :nocov:
          end

        attach_post_processor(rule_processor)

        self
      end

      def attach_post_processor(processor)
        if @post_processors
          @post_processors.attach(processor)
        else
          @post_processors = processor
        end
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
        callback = proc do |value, _name, error_builder|
          next self if error_builder.errors.any?

          instance_exec(value, error_builder, &block)
        end

        attach_post_processor(callback)

        self
      end

      # Check whether the field is matching the condition of the parent field.
      def inherit?(parent_field)
        child_type = @type
        parent_type = parent_field.type

        # Helper lambda to check subtype relationship between two NON-UNION types
        is_subtype_single = lambda do |c, p|
          if c.is_a?(Verse::Schema::Scalar) && p.is_a?(Verse::Schema::Scalar)
            c.values.all? { |c_val| p.values.any? { |p_val| c_val <= p_val } }
          elsif c.is_a?(Verse::Schema::Scalar) && p.is_a?(Class)
            c.values.all? { |c_val| c_val <= p }
          elsif c.is_a?(Class) && p.is_a?(Verse::Schema::Scalar)
            p.values.any? { |p_val| c <= p_val }
          elsif c.is_a?(Verse::Schema::Base) && p.is_a?(Verse::Schema::Base)
             c <= p
          elsif c.is_a?(Class) && p.is_a?(Class)
            c <= p
          else
            false # Incompatible types
          end
        end

        # Determine basic type compatibility based on single/union combinations
        types_compatible = \
          if child_type.is_a?(Array) && parent_type.is_a?(Array) # Union <= Union
            child_type.all? { |c_type| parent_type.any? { |p_type| is_subtype_single.call(c_type, p_type) } }
          elsif child_type.is_a?(Array) && !parent_type.is_a?(Array) # Union <= Single
            child_type.all? { |c_type| is_subtype_single.call(c_type, parent_type) }
          elsif !child_type.is_a?(Array) && parent_type.is_a?(Array) # Single <= Union
            parent_type.any? { |p_type| is_subtype_single.call(child_type, p_type) }
          else # Single <= Single
            is_subtype_single.call(child_type, parent_type)
          end

        # If basic types are not compatible, inheritance fails immediately.
        return false unless types_compatible

        # If basic types ARE compatible, proceed with option checks for refinement.
        if parent_field.opts[:schema]
          # Parent expects a specific nested schema structure (defined via block)
          # Child must be compatible (Hash or specific Struct/Dictionary) and its schema must inherit.
          (child_type.is_a?(Verse::Schema::Struct) || child_type.is_a?(Verse::Schema::Dictionary) || child_type == Hash) &&
            (
              !@opts[:schema] || # Child doesn't have a specific block schema (implicitly inherits)
              @opts[:schema] <= parent_field.opts[:schema] # Child's block schema inherits from parent's
            )
        elsif parent_field.opts[:of]
          # Parent is Collection/Dictionary defined via `of:`
          parent_of = parent_field.opts[:of]
          child_of = @opts[:of]

          # If parent expects specific contents (`of:`), child must comply.
          if parent_of
            # Child must also specify contents (`of:`) if parent does.
            return false unless child_of

            # Normalize `of` types to arrays for comparison
            child_of_array = child_of.is_a?(Array) ? child_of : [child_of]
            parent_of_array = parent_of.is_a?(Array) ? parent_of : [parent_of]

            # Check if child's `of` types inherit from parent's `of` types (recursive check)
            # This needs a recursive call to a method that can handle the full inheritance logic,
            # including the `of` checks. Let's assume `inherit?` can be called recursively here,
            # or we might need a dedicated helper. For simplicity, let's reuse `is_subtype_single`
            # for the `of` types for now, assuming `of` usually contains simple types or single schema types.
            # A more robust solution might need a full recursive `inherit?` check on temporary Field objects.
            child_of_array.all? do |c_of|
              parent_of_array.any? do |p_of|
                is_subtype_single.call(c_of, p_of) # Simplified check for `of` types
              end
            end
          else
            # Parent does not specify `of`, so child is compatible regardless of its `of`.
            true
          end
        else
          # Parent is not a block schema and not defined with `of:`. Basic type compatibility is enough.
          true
        end
      end

      def <=(other)
        (
          other.type == type &&
          other.opts[:schema] == opts[:schema] &&
          other.opts[:of] == opts[:of]
        ) || inherit?(other)
      end

      alias_method :<, :inherit?

      # :nodoc:
      def apply(value, output, error_builder, locals)
        locals[:__path__].push(@name)

        if @type.is_a?(Base)
          error_builder.context(@name) do |error_builder|
            result = @type.validate(value, error_builder:, locals:)

            # Apply field-level post-processors to the result of the nested schema validation
            output[@name] = if @post_processors && error_builder.errors.empty?
                              @post_processors.call(
                                result.value, @name, error_builder, **locals
                              )
                            else
                              result.value
                            end
          end
        else
          coalesced_value =
            Coalescer.transform(value, @type, @opts, locals:)

          if coalesced_value.is_a?(Result)
            error_builder.combine(@name, coalesced_value.errors)
            coalesced_value = coalesced_value.value
          end

          pp = @post_processors

          output[@name] = if pp
                            pp.call(
                              coalesced_value, @name, error_builder, **locals
                            )
                          else
                            coalesced_value
                          end
        end
      rescue Coalescer::Error => e
        error_builder.add(@name, e.message, **locals)
      ensure
        locals[:__path__].pop
      end
    end
  end
end

require_relative "./field/ext"

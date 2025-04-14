# frozen_string_literal: true

module Verse
  module Schema
    # Post type validation / coercion processor. Can act as semantic rule or
    # as a transformer.
    class PostProcessor
      END_OF_CHAIN = :end_of_chain

      attr_reader :next, :opts, :locals

      def initialize(**opts, &block)
        @opts = opts
        @block = block
      end

      def attach(processor)
        if @next
          @next.attach(processor)
        else
          @next = processor
        end
      end

      def stop
        throw END_OF_CHAIN, END_OF_CHAIN
      end

      def dup
        PostProcessor.new(**opts.dup, &@block).tap do |new_pp|
          new_pp.attach(@next.dup) if @next
        end
      end

      def then(&block)
        attach(PostProcessor.new(&block))
      end

      def call(value, key, error_builder, **locals)
        output = catch(END_OF_CHAIN) do
          @locals = locals
          instance_exec(value, error_builder, @opts, @locals, &@block)
        end

        return value if output == END_OF_CHAIN

        has_error = error_builder.errors.any?

        return value if has_error
        return output unless @next

        @next.call(output, key, error_builder, **locals)
      end
    end
  end
end

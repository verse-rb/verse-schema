# frozen_string_literal: true

module Verse
  module Schema
    # Post type validation / coercion processor. Can act as semantic rule or
    # as a transformer.
    class PostProcessor
      EndOfChain = :end_of_chain

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
        throw EndOfChain, EndOfChain
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
        output = catch(EndOfChain) do
          @locals = locals
          instance_exec(value, error_builder, @opts, @locals, &@block)
        end

        return value if output == EndOfChain

        has_error = error_builder.errors.any?

        if @next
          @next.call(output, key, error_builder, **locals)
        elsif has_error
          value
        else
          output
        end
      end
    end
  end
end

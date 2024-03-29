# frozen_string_literal: true

module Verse
  module Schema
    # Post type validation / coercion processor. Can act as semantic rule or
    # as a transformer.
    class PostProcessor
      EndOfChain = RuntimeError.new("End of chain")

      attr_reader :next, :opts

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
        raise EndOfChain
      end

      def dup
        PostProcessor.new(&@block).tap do |new_pp|
          new_pp.attach(@next.dup) if @next
        end
      end

      def then(&block)
        attach(PostProcessor.new(&block))
      end

      def call(value, key, error_builder)
        begin
          output = instance_exec(value, error_builder, @opts, &@block)
        rescue EndOfChain
          return value
        end

        has_error = error_builder.errors.any?

        if @next
          @next.call(output, key, error_builder)
        elsif has_error
          value
        else
          output
        end
      end
    end
  end
end

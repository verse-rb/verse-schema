# frozen_string_literal: true

module Verse
  module Schema
    class PostProcessor
      attr_reader :next, :opts

      def initialize(*opts, &block)
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

      def dup
        PostProcessor.new(&@block).tap do |new_pp|
          new_pp.attach(@next.dup) if @next
        end
      end

      def then(&block)
        attach(PostProcessor.new(&block))
      end

      def call(value, key, error_builder)
        has_error = false

        error = proc do |message, override_key = nil|
          has_error = true

          # NOTE: I'm not a big fan of this concept of overriding,
          # keys at error call. This is a bit smelly in my opinion
          key = override_key || key

          if key.is_a?(Array)
            key.each { |k| error_builder.add(k, message) }
          else
            error_builder.add(key, message)
          end
        end

        begin
          output = @block.call(value, error, @opts)
        rescue StandardError => e
          error.call(e.message)
        end

        if !has_error && @next
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

# frozen_string_literal: true

module Verse
  module Schema
    module Optionable
      NOTHING = Object.new

      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        def option(name, default: nil, &block)
          define_method(name) do |value = Verse::Schema::Optionable::NOTHING|
            if value == Verse::Schema::Optionable::NOTHING

              return instance_variable_get("@#{name}") if instance_variable_defined?("@#{name}")

              return instance_exec(&default) if default.is_a?(Proc)

              return default

            else
              instance_variable_set("@#{name}", block_given? ? block.call(value) : value)
            end

            self
          end
        end
      end
    end
  end
end

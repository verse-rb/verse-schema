# frozen_string_literal: true

module Verse
  module Schema
    module Optionable
      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        def option(name, default: nil)
          name = name.to_sym
          iv_name = "@#{name}".to_sym

          case default
          when Proc
            define_method(name) do |value = Nothing|
              if value == Nothing
                return instance_variable_get(iv_name) if instance_variable_defined?(iv_name)

                value = instance_exec(&default)
                instance_variable_set(iv_name, value)
                value
              else
                instance_variable_set(iv_name, block_given? ? yield(value) : value)
                self
              end
            end
          else
            define_method(name) do |value = Nothing|
              if value == Nothing
                return instance_variable_get(iv_name) if instance_variable_defined?(iv_name)

                default
              else
                instance_variable_set(iv_name, block_given? ? yield(value) : value)
                self
              end
            end
          end
        end
      end
    end
  end
end

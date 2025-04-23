# frozen_string_literal: true

require_relative "../../../spec_helper"

RSpec.describe "Under the hood", :readme do
  context "Add Custom coalescing rules", :readme_section do
    it "demonstrates custom type registration", skip: "Example only" do
      # This is an example of how to register a custom type
      # rubocop:disable Lint/ConstantDefinitionInBlock
      class Email
        def self.valid?(value)
          value.to_s.include?("@")
        end

        def initialize(value)
          @value = value
        end
      end
      # rubocop:enable Lint/ConstantDefinitionInBlock

      Verse::Schema::Coalescer.register(Email) do |value, _opts|
        case value
        when Email
          next value
        when String
          Email.valid?(value) && (next Email.new(value))
        end

        raise Verse::Schema::Coalescer::Error, "invalid email: #{value}"
      end

      # Usage example
      schema = Verse::Schema.define do
        field(:email, Email)
      end

      # Coalesce from a string:
      result = schema.validate({
        email: "example@domain.tld"
      })
      expect(result.success?).to be true
      expect(result.value[:email]).to be_a(Email)
    end
  end

  context "Reflecting on the schema", :readme_section do
    it "demonstrates schema reflection" do
      # It exists 4 schema class type:
      # 1. Verse::Schema::Struct
      #   the default schema type, with field definition
      # 2. Verse::Schema::Array
      #   a schema that contains an array of items
      #   `values` attribute being an array of type
      # 3. Verse::Schema::Dictionary
      #   a schema that contains a dictionary of items
      #   `values` attribute being an array of type
      # 4. Verse::Schema::Selector
      #   a schema that contains a selector of items
      #   `values` attribute being a selection hash
      complex_schema_example = Verse::Schema.define do
        field(:name, String).meta(label: "Name", description: "The name of the person")

        field(:data) do
          field(:content, String).filled
        end

        field(:dictionary, Verse::Schema.dictionary(String))
        field(:array, Array) do
          field(:item, [String, Integer])
        end
      end

      # Inspect is a good way to see the schema definition
      puts complex_schema_example.inspect
      # => #<struct{
      #   name: String,
      #   data: #<struct{content: String} 0x1400>,
      #   dictionary: #<dictionary<String> 0x1414>,
      #       array: #<collection<#<struct{item: String|Integer} 0x1428>> 0x143c>
      #   } 0x1450>

      # You can reflect on the schema to get information about its fields:
      expect(complex_schema_example.extra_fields?).to be false

      complex_schema_example.fields.each do |field|
        puts "Field name: #{field.name}"
        puts "Field type: #{field.type}"
        puts "Field metadata: #{field.meta}"

        puts "Is required: #{field.required?}"
      end

      # Of course, you can also traverse the schema tree to get information about nested fields:
      arr_value = complex_schema_example.fields.find{ |field| field.name == :array }.type.values
      puts arr_value[0].fields.map(&:name) # => [:item]
    end
  end

  context "Field Extensions", :readme_section do
    it "demonstrates adding features to fields", skip: "Example only" do
      # rubocop:disable Lint/ConstantDefinitionInBlock

      # For now, you can reopen the Field class to add macros or methods

      # Example of how to add helper methods to fields.
      # Those methods already exist in the Field class.
      # This is just an example of how to add them.
      module Verse
        module Schema
          class Field
            def filled(message = "must be filled")
              rule(message) do |value|
                if value.respond_to?(:empty?)
                  !value.empty?
                elsif !value
                  false
                else
                  true
                end
              end
            end

            def in?(values, message = "must be one of %s")
              rule(message % values.join(", ")) do |value|
                values.include?(value)
              end
            end
          end
        end
      end
      # rubocop:enable Lint/ConstantDefinitionInBlock

      # Example of adding optional information to fields
      Verse::Schema::Field.attr_chainable :data

      # Example of reflecting on the schema
      schema = Verse::Schema.define do
        field(:name, String).data("some additional data")
        field(:age, Integer).rule("must be 18 or older") { |age| age >= 18 }
      end

      schema.fields.each do |field|
        # Access field metadata
        field.name # => :name or :age
        field.data # => "some additional data" or nil
        field.type # => String or Integer
      end
    end
  end
end

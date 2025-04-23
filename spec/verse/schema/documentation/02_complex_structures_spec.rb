# frozen_string_literal: true

require_relative "../../../spec_helper"

RSpec.describe "2. Complex Structures", :readme do
  # Each context will represent a section in the README

  context "Nested Schemas", :readme_section do
    it "demonstrates nested schema usage" do
      # Define a simple schema first
      simple_schema = Verse::Schema.define do
        field(:name, String).meta(label: "Name", description: "The name of the person")
        field(:age, Integer).rule("must be 18 or older") { |age| age >= 18 }
      end

      # Nested schema using a reference
      nested_schema1 = Verse::Schema.define do
        field(:data, simple_schema)
      end

      # Validate nested data
      result = nested_schema1.validate({
        data: {
          name: "John",
          age: 30
        }
      })

      result.success? # => true
      result.value # => { data: { name: "John", age: 30 } }

      # Or define using subblock and Hash type
      nested_schema2 = Verse::Schema.define do
        field(:data, Hash) do
          field(:name, String).meta(label: "Name", description: "The name of the person")
          field(:age, Integer).rule("must be 18 or older") { |age| age >= 18 }
        end
      end

      # Both approaches produce equivalent schemas
      nested_schema2.validate({
        data: {
          name: "John",
          age: 30
        }
      }).success? # => true

      expect(result.success?).to be true
      expect(result.value).to eq({ data: { name: "John", age: 30 } })

      expect(nested_schema2.validate({
        data: {
          name: "John",
          age: 30
        }
      }).success?).to be true
    end
  end

  context "Array of Schemas", :readme_section do
    it "demonstrates array of schemas" do
      # Define an array of schemas using Array type
      array_schema = Verse::Schema.define do
        field(:data, Array) do
          field(:name, String).meta(label: "Name", description: "The name of the person")
          field(:age, Integer).rule("must be 18 or older") { |age| age >= 18 }
        end
      end

      # Validate an array of items
      result = array_schema.validate({
        data: [
          { name: "John", age: 30 },
          { name: "Jane", age: 25 }
        ]
      })

      # Check the result
      result.success? # => true
      result.value # => { data: [ { name: "John", age: 30 }, { name: "Jane", age: 25 } ] }

      # If any item in the array is invalid, the whole validation fails
      invalid_result = array_schema.validate({
        data: [
          { name: "John", age: 30 },
          { name: "Jane", age: 17 } # Age is invalid
        ]
      })

      invalid_result.success? # => false
      invalid_result.errors # => { "data.1.age": ["must be 18 or older"] }

      expect(result.success?).to be true
      expect(result.value).to eq({
        data: [
          { name: "John", age: 30 },
          { name: "Jane", age: 25 }
        ]
      })
      expect(invalid_result.success?).to be false
      expect(invalid_result.errors).to eq({ "data.1.age": ["must be 18 or older"] })
    end
  end

  context "Array of Any Type", :readme_section do
    it "demonstrates array of any type" do
      # Array of simple type using 'of' option
      array_schema1 = Verse::Schema.define do
        field(:data, Array, of: Integer)
      end

      # Validate array of integers (with automatic coercion)
      result = array_schema1.validate({
        data: [1, "2", "3"] # String values will be coerced to integers
      })

      result.success? # => true
      result.value # => { data: [1, 2, 3] }

      # This works with Schema too
      person_schema = Verse::Schema.define do
        field(:name, String)
        field(:age, Integer).rule("must be 18 or older") { |age| age >= 18 }
      end

      # Create an array of person schemas
      array_schema2 = Verse::Schema.define do
        field(:people, Array, of: person_schema)
      end

      # Validate array of people
      result2 = array_schema2.validate({
        people: [
          { name: "John", age: 30 },
          { name: "Jane", age: 25 }
        ]
      })

      result2.success? # => true

      expect(result.success?).to be true
      expect(result.value).to eq({ data: [1, 2, 3] })
      expect(result2.success?).to be true
    end
  end

  context "Dictionary Schema", :readme_section do
    it "demonstrates dictionary schemas" do
      # Define a dictionary schema with Integer values
      schema = Verse::Schema.define do
        field(:scores, Hash, of: Integer)
      end

      # Validate a dictionary
      result = schema.validate({
        scores: {
          math: "95",
          science: "87",
          history: 92.0
        }
      })

      # The validation succeeds and coerces string values to integers
      expect(result.success?).to be true
      expect(result.value).to eq({
        scores: {
          math: 95,
          science: 87,
          history: 92
        }
      })

      # Invalid values will cause validation to fail
      invalid_result = schema.validate({
        scores: {
          math: "95",
          science: "invalid",
          history: "92"
        }
      })
      expect(invalid_result.success?).to be false
      # Assuming error message for type coercion failure in dictionary
      expect(invalid_result.errors).to eq({ "scores.science": ["must be an integer"] })
    end
  end

  context "Recursive Schema", :readme_section do
    it "demonstrates recursive schema" do
      # Define a schema that can contain itself
      recursive_schema = Verse::Schema.define do
        field(:name, String).meta(label: "Name", description: "The name of the item")
        field(:children, Array, of: self).default([])
      end

      # This allows for tree-like structures
      tree_data = {
        name: "Root",
        children: [
          {
            name: "Child 1",
            children: [
              { name: "Grandchild 1" }
            ]
          },
          { name: "Child 2" }
        ]
      }

      # Validate the recursive structure
      result = recursive_schema.validate(tree_data)

      result.success? # => true

      # The validated data maintains the same structure
      # but with any coercions or transformations applied

      expect(result.success?).to be true
    end
  end

  context "Selector Based Type Selection", :readme_section do
    it "demonstrates using raw selector schema" do
      selector_schema = Verse::Schema.selector(
        a: [String, Integer],
        b: [Hash, Array]
      )

      result = selector_schema.validate("string", locals: { selector: :a })
      expect(result.success?).to be true

      result = selector_schema.validate(42, locals: { selector: :a })
      expect(result.success?).to be true

      result = selector_schema.validate({ key: "value" }, locals: { selector: :b })
      expect(result.success?).to be true
      result = selector_schema.validate([1, 2, 3], locals: { selector: :b })
      expect(result.success?).to be true

      # Invalid case - wrong type for the selector
      invalid_result = selector_schema.validate("invalid", locals: { selector: :b })
      expect(invalid_result.success?).to be false
      # Assuming error message format for type mismatch in selector
      # Currently, the error message will be related to the last type of the
      # array
      expect(invalid_result.errors).to eq({ nil => ["must be an array"] })

      # Invalid case - missing selector
      missing_selector_result = selector_schema.validate("invalid")
      expect(missing_selector_result.success?).to be false
      expect(missing_selector_result.errors).to eq({ nil => ["selector not provided for this schema"] })
    end

    it "demonstrates selector based type selection" do
      facebook_schema = Verse::Schema.define do
        field(:url, String)
        field?(:title, String)
      end

      google_schema = Verse::Schema.define do
        field(:search, String)
        field?(:location, String)
      end

      # Define a schema with a selector field
      schema = Verse::Schema.define do
        field(:type, Symbol).in?(%i[facebook google])
        field(:data, {
          facebook: facebook_schema,
          google: google_schema
        }, over: :type)
      end

      # Validate data with different types
      result1 = schema.validate({
        type: :facebook,
        data: { url: "https://facebook.com" }
      })

      result2 = schema.validate({
        type: :google,
        data: { search: "conference 2023" }
      })

      expect(result1.success?).to be true
      expect(result2.success?).to be true

      # Invalid case - wrong type for the selector
      invalid_result = schema.validate({
        type: :facebook,
        data: { search: "invalid" } # `search` is not in `facebook_schema`
      })

      expect(invalid_result.success?).to be false
      # Assuming error message format for missing required field in selected schema
      expect(invalid_result.errors).to eq({ "data.url": ["is required"] })
    end
  end
end

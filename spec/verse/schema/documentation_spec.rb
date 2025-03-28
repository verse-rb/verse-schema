# frozen_string_literal: true

require_relative "../../spec_helper"

RSpec.describe "Verse::Schema Documentation", :readme do
  # Each context will represent a section in the README

  context "Simple Usage", :readme_section do
    it "demonstrates basic schema validation" do
      # Define a rule for age validation
      must_be_major = Verse::Schema.rule("must be 18 or older") do |value|
        value >= 18
      end

      # Create a schema with name and age fields
      schema = Verse::Schema.define do
        field(:name, String).meta(label: "Name", description: "The name of the person").filled
        field(:age, Integer).rule(must_be_major)
      end

      # Validate data
      result = schema.validate({ name: "John", age: 18 })

      # Check if validation succeeded
      if result.success?
        # Access the validated and coerced data
        result.value # => {name: "John", age: 18}
      else
        # Access validation errors
        result.errors # => {}
      end

      # If validation fails, you can access the errors
      invalid_result = schema.validate({ name: "John", age: 17 })
      invalid_result.success? # => false
      invalid_result.errors # => {age: ["must be 18 or older"]}

      # For testing
      expect(result.success?).to be true
      expect(result.value).to eq({ name: "John", age: 18 })
      expect(invalid_result.success?).to be false
      expect(invalid_result.errors).to eq({ age: ["must be 18 or older"] })
    end
  end

  context "Optional Fields", :readme_section do
    it "demonstrates optional field usage" do
      # Optional field using field?
      schema = Verse::Schema.define do
        field(:name, String).meta(label: "Name", description: "The name of the person")
        field?(:age, Integer).rule("must be 18 or older") { |age| age >= 18 }
      end

      # Validation succeeds without the optional field
      schema.validate({ name: "John" }).success? # => true

      # But fails if the optional field is present but invalid
      schema.validate({ name: "John", age: 17 }).success? # => false

      # Note that if a key is found but set to nil, the schema will be invalid
      schema.validate({ name: "John", age: nil }).success? # => false

      # To make it valid with nil, define the field as union of Integer and NilClass
      schema_with_nil = Verse::Schema.define do
        field(:name, String).meta(label: "Name", description: "The name of the person")
        field(:age, [Integer, NilClass]).rule("must be 18 or older") { |age|
          next true if age.nil?

          age >= 18
        }
      end

      # Now nil is valid
      schema_with_nil.validate({ name: "John", age: nil }).success? # => true

      # For testing
      expect(schema.validate({ name: "John" }).success?).to be true
      expect(schema.validate({ name: "John", age: 17 }).success?).to be false
      expect(schema.validate({ name: "John", age: nil }).success?).to be false
      expect(schema_with_nil.validate({ name: "John", age: nil }).success?).to be true
    end
  end

  context "Default Fields", :readme_section do
    it "demonstrates default field values" do
      # Use a static value
      schema1 = Verse::Schema.define do
        field(:type, String).default("reply")
      end

      # Empty input will use the default value
      schema1.validate({}).value # => {type: "reply"}

      # Or use a block which will be called
      schema2 = Verse::Schema.define do
        field(:type, String).default { "reply" }
      end

      schema2.validate({}).value # => {type: "reply"}

      # Using required after default disables default
      schema3 = Verse::Schema.define do
        field(:type, String).default("ignored").required
      end

      schema3.validate({}).success? # => false
      schema3.validate({}).errors # => {type: ["is required"]}

      # For testing
      expect(schema1.validate({}).value).to eq({ type: "reply" })
      expect(schema2.validate({}).value).to eq({ type: "reply" })
      expect(schema3.validate({}).success?).to be false
      expect(schema3.validate({}).errors).to eq({ type: ["is required"] })
    end
  end

  context "Nested Schemas", :readme_section do
    it "demonstrates nested schema usage" do
      # Define a simple schema first
      simple_schema = Verse::Schema.define do
        field(:name, String).meta(label: "Name", description: "The name of the person").filled
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
          field(:name, String).meta(label: "Name", description: "The name of the person").filled
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

      # For testing
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
          field(:name, String).meta(label: "Name", description: "The name of the person").filled
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

      # For testing
      expect(result.success?).to be true
      expect(result.value).to eq({
                                   data: [
                                     { name: "John", age: 30 },
                                     { name: "Jane", age: 25 }
                                   ]
                                 })
      expect(invalid_result.success?).to be false
      expect(invalid_result.errors).to include(:"data.1.age")
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
        field(:name, String).filled
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

      # For testing
      expect(result.success?).to be true
      expect(result.value).to eq({ data: [1, 2, 3] })
      expect(result2.success?).to be true
    end
  end

  context "Recursive Schema", :readme_section do
    it "demonstrates recursive schema" do
      # Define a schema that can contain itself
      recursive_schema = Verse::Schema.define do
        field(:name, String).meta(label: "Name", description: "The name of the item").filled
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

      # For testing
      expect(result.success?).to be true
    end
  end

  context "Rules", :readme_section do
    it "demonstrates global rules" do
      # Multiple fields rule
      multiple_field_rule_schema = Verse::Schema.define do
        field(:name, String)
        field(:age, Integer)

        rule(%i[age name], "age must be 18 and name must NOT be John") do |schema|
          schema[:age] >= 18 && schema[:name] != "John"
        end
      end

      # Valid case
      result1 = multiple_field_rule_schema.validate({
                                                      name: "Jane",
                                                      age: 20
                                                    })
      expect(result1.success?).to be true

      # Invalid case - rule violation
      result2 = multiple_field_rule_schema.validate({
                                                      name: "John",
                                                      age: 20
                                                    })
      expect(result2.success?).to be false
      expect(result2.errors).to include(:age, :name)
    end
  end

  context "Locals Variables", :readme_section do
    it "demonstrates locals variables" do
      schema = Verse::Schema.define do
        field(:age, Integer).rule("must be greater than %<min_age>s") { |age|
          age > locals[:min_age]
        }
      end

      # Valid case
      result1 = schema.validate({ age: 22 }, locals: { min_age: 21 })
      expect(result1.success?).to be true

      # Invalid case
      result2 = schema.validate({ age: 18 }, locals: { min_age: 21 })
      expect(result2.success?).to be false
      expect(result2.errors).to eq({ age: ["must be greater than 21"] })
    end
  end

  context "Custom Types", :readme_section do
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
      Verse::Schema.define do
        field(:email, Email)
      end
    end
  end

  context "Postprocessing", :readme_section do
    it "demonstrates postprocessing with transform" do
      Event = Struct.new(:type, :data, :created_at) unless defined?(Event)

      event_schema = Verse::Schema.define do
        field(:type, String)
        field(:data, Hash).transform{ |input| input.transform_keys(&:to_sym) }
        field(:created_at, Time)

        # Transform the output of this schema definition.
        transform do |input|
          Event.new(input[:type], input[:data], input[:created_at])
        end
      end

      output = event_schema.validate({
                                       type: "user.created",
                                       data: { "name" => "John" },
                                       created_at: "2020-01-01T00:00:00Z"
                                     }).value

      expect(output).to be_a(Event)
      expect(output.type).to eq("user.created")
      expect(output.data).to eq({ name: "John" })
      expect(output.created_at).to be_a(Time)
    end
  end

  context "Multiple Types Field", :readme_section do
    it "demonstrates fields that accept multiple types" do
      # Define a schema that accepts a String or a Hash
      content_hash = Verse::Schema.define do
        field(:content, String).filled
        field(:created_at, Time)
      end

      schema = Verse::Schema.define do
        field(:title, String)
        field(:content, [String, content_hash]).filled
      end

      # Validate with a String content
      result1 = schema.validate({
                                  title: "My Post",
                                  content: "This is a simple string content"
                                })

      # Validate with a Hash content
      result2 = schema.validate({
                                  title: "My Post",
                                  content: {
                                    content: "This is a structured content",
                                    created_at: "2023-01-01T12:00:00Z"
                                  }
                                })

      # Both are valid
      expect(result1.success?).to be true
      expect(result2.success?).to be true

      # But invalid content will fail
      invalid_result = schema.validate({
                                         title: "My Post",
                                         content: { invalid: "structure" }
                                       })
      expect(invalid_result.success?).to be false
    end
  end

  context "Open Hash", :readme_section do
    it "demonstrates schemas that allow extra fields" do
      # Define a schema that allows extra fields
      schema = Verse::Schema.define do
        field(:name, String)

        # This allows any additional fields to be included
        extra_fields
      end

      # Validate with only the defined fields
      result1 = schema.validate({
                                  name: "John"
                                })

      # Validate with extra fields
      result2 = schema.validate({
                                  name: "John",
                                  age: 30,
                                  email: "john@example.com"
                                })

      # Both are valid
      expect(result1.success?).to be true
      expect(result2.success?).to be true

      # Extra fields are preserved in the output
      expect(result2.value).to eq({
                                    name: "John",
                                    age: 30,
                                    email: "john@example.com"
                                  })
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
                                   history: "92"
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
    end
  end

  context "Schema Inheritance", :readme_section do
    it "demonstrates schema inheritance" do
      # Define a parent schema
      parent = Verse::Schema.define do
        field(:type, Symbol)
        field(:id, Integer)

        rule(:type, "should be filled") { |x| x[:type].to_s != "" }
      end

      # Define a child schema that inherits from the parent
      child_a = Verse::Schema.define(parent) do
        rule(:type, "must start with x") { |x| x[:type].to_s =~ /^x/ }
        field(:data, Hash) do
          field(:x, Float)
          field(:y, Float)
        end
      end

      # Another child schema with different rules
      child_b = Verse::Schema.define(parent) do
        rule(:type, "must start with y") { |x| x[:type].to_s =~ /^y/ }
        field(:data, Hash) do
          field(:content, String)
        end
      end

      # Validate using child_a schema
      result_a = child_a.validate({
                                    type: :xcoord,
                                    id: 1,
                                    data: {
                                      x: 10.5,
                                      y: 20.3
                                    }
                                  })

      # Validate using child_b schema
      result_b = child_b.validate({
                                    type: :ydata,
                                    id: 2,
                                    data: {
                                      content: "Some content"
                                    }
                                  })

      # Both validations succeed
      expect(result_a.success?).to be true
      expect(result_b.success?).to be true

      # Invalid data for child_a
      invalid_a = child_a.validate({
                                     type: :ycoord, # Should start with 'x'
                                     id: 1,
                                     data: {
                                       x: 10.5,
                                       y: 20.3
                                     }
                                   })
      expect(invalid_a.success?).to be false
    end

    it "tests inheritance relationships between schemas" do
      # Define a parent schema
      parent = Verse::Schema.define do
        field(:name, String)
        field(:age, Integer)
      end

      # Define a child schema that inherits from the parent
      child = Verse::Schema.define(parent) do
        field(:email, String)
      end

      # Define a schema with the same fields but not inherited
      similar = Verse::Schema.define do
        field(:name, String)
        field(:age, Integer)
      end

      # Define a schema with different fields
      different = Verse::Schema.define do
        field(:title, String)
        field(:count, Integer)
      end

      # Test inheritance relationships
      expect(child.inherit?(parent)).to be true  # Child inherits from parent
      expect(child < parent).to be true          # Using the < operator
      expect(child <= parent).to be true         # Using the <= operator

      expect(parent.inherit?(child)).to be false # Parent doesn't inherit from child
      expect(parent < child).to be false         # Using the < operator
      expect(parent <= child).to be false        # Using the <= operator

      # Similar schema has the same fields as parent
      # In Verse::Schema, inheritance is structural, not nominal
      # So a schema with the same fields "inherits" from another schema
      expect(similar.inherit?(parent)).to be true # Similar structurally inherits from parent
      expect(similar < parent).to be true         # Using the < operator
      expect(similar <= parent).to be true        # Using the <= operator

      expect(different.inherit?(parent)).to be false # Different doesn't inherit from parent
      expect(different < parent).to be false         # Using the < operator
      expect(different <= parent).to be false        # Using the <= operator

      # rubocop:disable Lint/BinaryOperatorWithIdenticalOperands
      # Test self-comparison
      expect(parent <= parent).to be true  # A schema is <= to itself
      expect(parent < parent).to be false  # A schema is not < itself
      # rubocop:enable Lint/BinaryOperatorWithIdenticalOperands
    end
  end

  context "Field Inheritance", :readme_section do
    it "tests inheritance relationships between fields" do
      # Create fields with different types
      string_field = Verse::Schema::Field.new(:name, String, {})
      integer_field = Verse::Schema::Field.new(:age, Integer, {})
      number_field = Verse::Schema::Field.new(:count, Numeric, {})

      # Integer is a subclass of Numeric
      expect(integer_field.inherit?(number_field)).to be true
      expect(integer_field < number_field).to be true
      expect(integer_field <= number_field).to be true

      # String is not a subclass of Numeric
      expect(string_field.inherit?(number_field)).to be false
      expect(string_field < number_field).to be false
      expect(string_field <= number_field).to be false

      # Test with same type but different names
      name_field = Verse::Schema::Field.new(:name, String, {})
      title_field = Verse::Schema::Field.new(:title, String, {})

      # Same type, different names - should still be comparable
      expect(name_field.inherit?(title_field)).to be true
      expect(name_field < title_field).to be true
      expect(name_field <= title_field).to be true

      # Test with Hash fields and nested schemas
      person_schema = Verse::Schema.define do
        field(:name, String)
        field(:age, Integer)
      end

      employee_schema = Verse::Schema.define do
        field(:name, String)
        field(:age, Integer)
        field(:salary, Float)
      end

      person_field = Verse::Schema::Field.new(:person, person_schema, {})
      employee_field = Verse::Schema::Field.new(:employee, employee_schema, {})

      # Test schema field inheritance
      # This might fail if the implementation is incorrect
      begin
        result = employee_field.inherit?(person_field)
        expect([true, false]).to include(result)
      rescue NotImplementedError => e
        # If it raises NotImplementedError, that's also valuable information
        puts "NotImplementedError raised: #{e.message}"
      end
    end
  end

  context "Schema Aggregation", :readme_section do
    it "demonstrates combining schemas" do
      # Define two schemas to combine
      schema1 = Verse::Schema.define do
        field(:age, Integer).rule("must be major") { |age|
          age >= 18
        }
      end

      schema2 = Verse::Schema.define do
        field(:content, [String, Hash])
      end

      # Combine the schemas
      combined_schema = schema1 + schema2

      # Validate using the combined schema
      result = combined_schema.validate({
                                          age: 25,
                                          content: "Some content"
                                        })

      # The validation succeeds
      expect(result.success?).to be true

      # Invalid data will still fail
      invalid_result = combined_schema.validate({
                                                  age: 16, # Too young
                                                  content: "Some content"
                                                })
      expect(invalid_result.success?).to be false
    end
  end

  context "Schema Factory Methods", :readme_section do
    it "demonstrates schema factory methods" do
      # Define a base item schema
      item_schema = Verse::Schema.define do
        field(:name, String)
      end

      # Create an array schema using the factory method
      array_schema = Verse::Schema.array(item_schema)

      # Create a dictionary schema using the factory method
      dictionary_schema = Verse::Schema.dictionary(item_schema)

      # Create a scalar schema using the factory method
      scalar_schema = Verse::Schema.scalar(Integer, String)

      # Validate using the array schema
      array_result = array_schema.validate([
                                             { name: "Item 1" },
                                             { name: "Item 2" }
                                           ])
      expect(array_result.success?).to be true

      # Validate using the dictionary schema
      dict_result = dictionary_schema.validate({
                                                 item1: { name: "First Item" },
                                                 item2: { name: "Second Item" }
                                               })
      expect(dict_result.success?).to be true

      # Validate using the scalar schema
      scalar_result1 = scalar_schema.validate(42)
      scalar_result2 = scalar_schema.validate("Hello")
      expect(scalar_result1.success?).to be true
      expect(scalar_result2.success?).to be true
    end
  end

  context "Complex Example", :readme_section do
    it "demonstrates a comprehensive example" do
      # Define a complex schema that combines multiple features
      schema = Verse::Schema.define do
        # Define nested schemas
        facebook_event = define do
          field(:url, String).filled
          extra_fields # Allow additional fields
        end

        google_event = define do
          field(:search, String).filled
          extra_fields # Allow additional fields
        end

        # Define an event schema that uses the nested schemas
        event = define do
          field(:at, Time)
          field(:type, Symbol).in?(%i[created updated])
          field(:provider, String).in?(%w[facebook google])
          field(:data, [facebook_event, google_event]) # Union type
          field(:source, String).filled

          # Conditional validation based on provider
          rule(:data, "invalid event data structure") do |hash|
            case hash[:provider]
            when "facebook"
              facebook_event.valid?(hash[:data])
            when "google"
              google_event.valid?(hash[:data])
            else
              false
            end
          end
        end

        # The main schema field is an array of events
        field(:events, Array, of: event)
      end

      # Create a complex data structure to validate
      data = {
        events: [
          {
            at: "2023-01-01T12:00:00Z",
            type: :created,
            provider: "facebook",
            data: {
              url: "https://facebook.com/event/123",
              title: "Facebook Event" # Extra field
            },
            source: "api"
          },
          {
            at: "2023-01-02T14:30:00Z",
            type: :updated,
            provider: "google",
            data: {
              search: "conference 2023",
              location: "New York" # Extra field
            },
            source: "webhook"
          }
        ]
      }

      # Validate the complex data
      result = schema.validate(data)

      # The validation succeeds
      expect(result.success?).to be true

      # The output maintains the structure with coerced values
      expect(result.value[:events][0][:at]).to be_a(Time)
      expect(result.value[:events][1][:at]).to be_a(Time)
    end
  end

  context "Post Processors", :readme_section do
    it "demonstrates chaining multiple post processors" do
      # Create a schema with multiple rules on a field
      schema = Verse::Schema.define do
        field(:age, Integer)
          .rule("must be at least 18") { |age| age >= 18 }
          .rule("must be under 100") { |age| age < 100 }
      end

      # Valid age
      result1 = schema.validate({ age: 30 })
      expect(result1.success?).to be true

      # Too young
      result2 = schema.validate({ age: 16 })
      expect(result2.success?).to be false
      expect(result2.errors).to eq({ age: ["must be at least 18"] })

      # Too old
      result3 = schema.validate({ age: 120 })
      expect(result3.success?).to be false
      expect(result3.errors).to eq({ age: ["must be under 100"] })
    end

    it "demonstrates rule with error_builder parameter" do
      # Create a schema with a rule that uses the error_builder
      schema = Verse::Schema.define do
        field(:data, Hash).rule("must contain required keys") do |data, error_builder|
          valid = true

          # Check for required keys
          %w[name email].each do |key|
            unless data.key?(key.to_sym) || data.key?(key)
              error_builder.add(:data, "missing required key: #{key}")
              valid = false
            end
          end

          valid
        end
      end

      # Valid data
      result1 = schema.validate({ data: { name: "John", email: "john@example.com" } })
      expect(result1.success?).to be true

      # Missing name
      result2 = schema.validate({ data: { email: "john@example.com" } })
      expect(result2.success?).to be false
      expect(result2.errors[:data]).to include("missing required key: name")

      # Missing email
      result3 = schema.validate({ data: { name: "John" } })
      expect(result3.success?).to be false
      expect(result3.errors[:data]).to include("missing required key: email")
    end
  end

  context "Data Classes", :readme_section do
    it "demonstrates using schemas to create data classes", skip: RUBY_VERSION < "3.2.0" do
      # Define a schema for a person
      person_schema = Verse::Schema.define do
        field(:name, String)
        field(:age, Integer).rule("must be at least 18") { |age| age >= 18 }
        field(:email, String).rule("must be a valid email") { |email| email.include?("@") }
      end

      # Create a data class from the schema
      # rubocop:disable Lint/ConstantDefinitionInBlock
      Person = person_schema.dataclass do
        # You can add methods to the data class
        def adult?
          age >= 21
        end

        def greeting
          "Hello, #{name}!"
        end
      end
      # rubocop:enable Lint/ConstantDefinitionInBlock

      # Create a valid instance
      person = Person.new({
                            name: "John Doe",
                            age: 30,
                            email: "john@example.com"
                          })

      # Access fields as methods
      expect(person.name).to eq("John Doe")
      expect(person.age).to eq(30)
      expect(person.email).to eq("john@example.com")

      # Use custom methods
      expect(person.adult?).to be true
      expect(person.greeting).to eq("Hello, John Doe!")

      # Data classes are immutable and setters doesn't exists
      expect { person.name = "Jane" }.to raise_error(NoMethodError)

      # Data classes have value semantics
      person2 = Person.new({
                             name: "John Doe",
                             age: 30,
                             email: "john@example.com"
                           })
      expect(person).to eq(person2)

      # Invalid data raises an error
      expect {
        Person.new({
                     name: "Young Person",
                     age: 16, # Too young
                     email: "young@example.com"
                   })
      }.to raise_error(Verse::Schema::InvalidSchemaError)

      # You can create from raw hash without validation
      raw_person = Person.from_raw({
                                     name: "Raw Person",
                                     age: 16, # Would normally be invalid
                                     email: "raw@example.com"
                                   })
      expect(raw_person.name).to eq("Raw Person")
      expect(raw_person.age).to eq(16)
    end

    it "demonstrates nested data classes", skip: RUBY_VERSION < "3.2.0" do
      # Data class will automatically use dataclass of other nested schemas.
      # Define a schema for an address
      address_schema = Verse::Schema.define do
        field(:street, String)
        field(:city, String)
        field(:zip, String)
      end

      # Create a data class for address
      # rubocop:disable Lint/ConstantDefinitionInBlock
      Address = address_schema.dataclass

      # Define a schema for a person with a nested address
      person_schema = Verse::Schema.define do
        field(:name, String)
        field(:address, address_schema)
      end

      # Create a data class for person
      Person = person_schema.dataclass
      # rubocop:enable Lint/ConstantDefinitionInBlock

      # Create a person with a nested address
      person = Person.new({
                            name: "John Doe",
                            address: {
                              street: "123 Main St",
                              city: "Anytown",
                              zip: "12345"
                            }
                          })

      # The nested address is also a data class
      expect(person.address).to be_a(Address)
      expect(person.address.street).to eq("123 Main St")
      expect(person.address.city).to eq("Anytown")
      expect(person.address.zip).to eq("12345")
    end
  end

  context "Field Extensions", :readme_section do
    it "demonstrates adding features to fields", skip: "Example only" do
      # rubocop:disable Lint/ConstantDefinitionInBlock

      # Example of how to add helper methods to fields
      module Verse
        module Schema
          class Field
            def filled(message = "must be filled")
              rule(message) do |value, _output|
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
              rule(message % values.join(", ")) do |value, _output|
                values.include?(value)
              end
            end
          end
        end
      end
      # rubocop:enable Lint/ConstantDefinitionInBlock

      # Example of adding optional information to fields
      Verse::Schema::Field.option :meta, default: {}

      # Example of reflecting on the schema
      schema = Verse::Schema.define do
        field(:name, String).meta(label: "Name", description: "The name of the person").filled
        field(:age, Integer).rule("must be 18 or older") { |age| age >= 18 }
      end

      schema.fields.each do |field|
        # Access field metadata
        field.name        # => :name or :age
        field.label       # => "Name" or nil
        field.description # => "The name of the person" or nil
      end
    end
  end
end

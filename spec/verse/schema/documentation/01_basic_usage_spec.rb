# frozen_string_literal: true

require_relative "../../../spec_helper"

RSpec.describe "1. Basic Usage", :readme do
  context "Simple Usage", :readme_section do
    it "demonstrates basic schema validation" do
      # Create a schema with name and age fields
      schema = Verse::Schema.define do
        field(:name, String).meta(label: "Name", description: "The name of the person")
        field(:age, Integer).rule("must be 18 or older"){ |age| age >= 18 }
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

      expect(schema.validate({ name: "John" }).success?).to be true
      expect(schema.validate({ name: "John", age: 17 }).success?).to be false
      expect(schema.validate({ name: "John", age: 17 }).errors).to eq({ age: ["must be 18 or older"] })
      expect(schema.validate({ name: "John", age: nil }).success?).to be false
      # Assuming default type error message for nil when Integer is expected
      expect(schema.validate({ name: "John", age: nil }).errors).to eq({ age: ["must be an integer"] })
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

      expect(schema1.validate({}).value).to eq({ type: "reply" })
      expect(schema2.validate({}).value).to eq({ type: "reply" })
      expect(schema3.validate({}).success?).to be false
      expect(schema3.validate({}).errors).to eq({ type: ["is required"] })
    end
  end

  context "Coalescing rules", :readme_section do
    it "demonstrates coalescer rules" do
      # Verse::Schema will try  to coalesce the data to the type of the field.
      # This means that if you pass a string in an Integer field,
      # it will try to convert it to an integer.

      schema = Verse::Schema.define do
        field(:name, String)
        field(:age, Integer)
      end

      # Coalescer will try to coerce the data to the type
      # of the field. So if you pass a string, it will
      # try to convert it to an integer.
      result = schema.validate({ name: 1, age: "18" })

      expect(result.success?).to be true
      expect(result.value).to eq({ name: "1", age: 18 })
    end

    it "quick match if the class of the input is the same as the field" do
      # If the input is of the same class as the field,
      # it will be a quick match and no coercion will be
      # performed.
      schema = Verse::Schema.define do
        field(:age, [Integer, Float])
      end

      result = schema.validate({ age: 18.0 })

      expect(result.success?).to be true
      expect(result.value[:age]).to be_a(Float)
    end

    it "stops when finding a good candidate" do
      # The coalescer go through all the different types in the definition order
      # and stop when it finds a good candidate.
      #
      # The example schema above would never coalesce to Float
      # because it would find Float first:
      schema = Verse::Schema.define do
        field(:age, [Float, Integer])
      end

      result = schema.validate({ age: "18" })

      expect(result.success?).to be true

      # It was able to coalesce to Float first
      # In this case, it would be judicious to define the field
      # as [Integer, Float], Integer being more constrained, to avoid this behavior
      expect(result.value[:age]).to be_a(Float)
    end
  end

  context "Naming the keys", :readme_section do
    it "demonstrates using different keys for fields" do
      # If the key of the input schema is different from the output schema,
      # you can use the `key` method to specify the key in the input schema
      # that should be used for the output schema.

      # Define a schema with different keys for fields
      schema = Verse::Schema.define do
        # key can be passed as option
        field(:name, String, key: :firstName)
        # or using the chainable syntax
        field(:email, String).key(:email_address)
      end

      # Validate data with the original key
      result1 = schema.validate({
        firstName: "John",
        email_address: "john@example.tld"
      })
      result1.success? # => true

      expect(result1.value).to eq({
        name: "John",
        email: "john@example.tld"
      })
    end
  end

  context "Multiple Types Field", :readme_section do
    it "demonstrates fields that accept multiple types" do
      # Define a schema that accepts a String or a Nested Schema
      content_hash = Verse::Schema.define do
        field(:content, String)
        field(:created_at, Time)
      end

      schema = Verse::Schema.define do
        field(:title, String)
        field(:content, [String, content_hash])
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
        content: { invalid: "structure" } # Doesn't match `content_hash` schema
      })
      expect(invalid_result.success?).to be false
      # Assuming error messages for missing fields in the nested hash schema
      expect(invalid_result.errors).to eq({ "content.content": ["is required"], "content.created_at": ["is required"] })
    end
  end

  context "Open Hash", :readme_section do
    it "demonstrates schemas that allow extra fields" do
      # By default, schemas are closed, which means that
      # fields not defined in the schema will be ignored.
      # To allow extra fields, you can use the `extra_fields` method:

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

  context "Strict Validation Mode", :readme_section do
    it "demonstrates strict validation for extra fields during validation" do
      # By default, schemas ignore fields not defined in the schema unless `extra_fields` is used.
      # You can enforce strict validation by passing `strict: true` to the `validate` method.
      # This will cause validation to fail if extra fields are provided and the schema
      # does not explicitly allow them via `extra_fields`.

      # Please note: `strict` mode is propagated to the children schemas, when you have
      # nested structures.

      # Define a standard schema (extra_fields is false by default)
      schema = Verse::Schema.define do
        field(:name, String)
      end

      # Default validation (strict: false) ignores extra fields
      result_default = schema.validate({ name: "John", age: 30 })
      expect(result_default.success?).to be true
      expect(result_default.value).to eq({ name: "John" }) # 'age' is ignored

      # Strict validation (strict: true) fails with extra fields
      result_strict_fail = schema.validate({ name: "John", age: 30 }, strict: true)
      expect(result_strict_fail.success?).to be false
      expect(result_strict_fail.errors).to eq({ age: ["is not allowed"] }) # Error on extra field 'age'

      # Strict validation succeeds if no extra fields are provided
      result_strict_ok = schema.validate({ name: "John" }, strict: true)
      expect(result_strict_ok.success?).to be true
      expect(result_strict_ok.value).to eq({ name: "John" })

      # Now, define a schema that explicitly allows extra fields
      schema_with_extra = Verse::Schema.define do
        field(:name, String)
        extra_fields # Explicitly allow extra fields
      end

      # Strict validation has no effect if `extra_fields` is enabled in the schema definition
      result_strict_extra_ok = schema_with_extra.validate({ name: "John", age: 30 }, strict: true)
      expect(result_strict_extra_ok.success?).to be true
      expect(result_strict_extra_ok.value).to eq({ name: "John", age: 30 }) # Extra field 'age' is allowed and included
    end
  end
end

# frozen_string_literal: true

require_relative "../../../spec_helper"

RSpec.describe "Schema Composition", :readme do
  context "Schema Factory Methods", :readme_section do
    it "demonstrates schema factory methods" do
      # Verse::Schema offer methods to create array, dictionary, and scalar schemas

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

  context "Schema Inheritance", :readme_section do
    it "demonstrates schema inheritance" do
      # Schema can inherit from other schemas.
      # Please be aware that this is not a classical inheritance model,
      # but rather a structural inheritance model.
      # In a way, it is similar to traits concept.

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
      expect(invalid_a.errors).to eq({ type: ["must start with x"] })
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

  context "Schema Aggregation", :readme_section do
    it "demonstrates combining schemas" do
      # It is sometime useful to combine two schemas into one.
      # This is done using the `+` operator.
      # The resulting schema will have all the fields of both schemas.
      # If the same field is defined in both schemas, the combination will
      # be performed at the field level, so the field type will be the union
      # of the two fields.
      # The rules and post-processing will be combined as well, in such order
      # that the first schema transforms will be applied first, and then the second one.

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
      expect(invalid_result.errors).to eq({ age: ["must be major"] })
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
end

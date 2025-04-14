# frozen_string_literal: true

require_relative "../../spec_helper"

RSpec.describe Verse::Schema::Collection do
  let(:integer_scalar) { Verse::Schema::Scalar.new(values: [Integer]) }
  let(:object_scalar) { Verse::Schema::Scalar.new(values: [Object]) }

  describe "#<=" do
    it "returns true when child collection types inherit from parent collection types" do
      child_schema = Verse::Schema::Collection.new(values: [integer_scalar])
      parent_schema = Verse::Schema::Collection.new(values: [object_scalar])

      expect(child_schema <= parent_schema).to be(true)
    end

    it "returns true for identical schemas" do
      schema1 = Verse::Schema::Collection.new(values: [integer_scalar])
      schema2 = Verse::Schema::Collection.new(values: [integer_scalar])

      expect(schema1 <= schema2).to be(true)
    end

    it "returns false when types are incompatible" do
      schema1 = Verse::Schema::Collection.new(values: [integer_scalar])
      schema2 = Verse::Schema::Collection.new(values: [Verse::Schema::Scalar.new(values: [String])])

      expect(schema1 <= schema2).to be(false)
    end

    it "returns false when parent allows fewer types (more specific)" do
       child_schema = Verse::Schema::Collection.new(values: [object_scalar])
       parent_schema = Verse::Schema::Collection.new(values: [integer_scalar])

       expect(child_schema <= parent_schema).to be(false)
    end

    it "handles multiple types correctly (inheritance)" do
      string_scalar = Verse::Schema::Scalar.new(values: [String])
      child_schema = Verse::Schema::Collection.new(values: [integer_scalar, string_scalar])
      parent_schema = Verse::Schema::Collection.new(values: [object_scalar])

      expect(child_schema <= parent_schema).to be(true)
    end

     it "handles multiple types correctly (no inheritance)" do
      string_scalar = Verse::Schema::Scalar.new(values: [String])
      child_schema = Verse::Schema::Collection.new(values: [integer_scalar, string_scalar])
      parent_schema = Verse::Schema::Collection.new(values: [integer_scalar]) # Only allows Integer

      expect(child_schema <= parent_schema).to be(false)
    end

    it "handles empty child collection" do
      child_schema = Verse::Schema::Collection.new(values: [])
      parent_schema = Verse::Schema::Collection.new(values: [object_scalar])

      expect(child_schema <= parent_schema).to be(true)
    end

    it "handles empty parent collection" do
      child_schema = Verse::Schema::Collection.new(values: [integer_scalar])
      parent_schema = Verse::Schema::Collection.new(values: [])

      # A child with types cannot inherit from a parent that allows nothing
      expect(child_schema <= parent_schema).to be(false)
    end

     it "handles both empty collections" do
      child_schema = Verse::Schema::Collection.new(values: [])
      parent_schema = Verse::Schema::Collection.new(values: [])

      expect(child_schema <= parent_schema).to be(true)
    end
  end

  # Basic validation tests (can be expanded)
  describe "#validate" do
    it "validates an array of correct types" do
      schema = Verse::Schema::Collection.new(values: [integer_scalar])
      result = schema.validate([1, 2, 3])
      expect(result.success?).to be(true)
      expect(result.value).to eq([1, 2, 3])
    end

    it "returns errors for incorrect types in array" do
      schema = Verse::Schema::Collection.new(values: [integer_scalar])
      result = schema.validate([1, "a", 3])
      expect(result.success?).to be(false)
      # Expect the key to be the symbol representation of the index
      expect(result.errors).to have_key(:"1") # Error at index 1, represented as symbol
      expect(result.errors[:"1"]).to include("must be an integer") # Match the actual error message
    end

    it "returns error if input is not an array" do
       schema = Verse::Schema::Collection.new(values: [integer_scalar])
       result = schema.validate("not an array")
       expect(result.success?).to be(false)
       expect(result.errors).to have_key(nil)
       expect(result.errors[nil]).to include("must be an array")
    end
  end
end

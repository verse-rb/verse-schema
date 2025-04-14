# frozen_string_literal: true

require_relative "../../spec_helper"

RSpec.describe Verse::Schema::Field do
  let(:integer_scalar) { Verse::Schema::Scalar.new(values: [Integer]) }
  let(:object_scalar) { Verse::Schema::Scalar.new(values: [Object]) }
  let(:string_scalar) { Verse::Schema::Scalar.new(values: [String]) }

  let(:collection_of_integers) { Verse::Schema::Collection.new(values: [integer_scalar]) }
  let(:collection_of_objects) { Verse::Schema::Collection.new(values: [object_scalar]) }
  # Mimic the structure from the error report: Collection<Array<Scalar<Integer>>>
  let(:collection_of_integer_arrays) { Verse::Schema::Collection.new(values: [[integer_scalar]]) }

  describe "#inherit?" do
    context "when comparing types directly" do
      it "returns true if child type inherits from parent type (Scalar)" do
        child_field = Verse::Schema::Field.new(:data, Integer, {})
        parent_field = Verse::Schema::Field.new(:data, Object, {})
        expect(child_field.inherit?(parent_field)).to be(true)
      end

      it "returns false if child type does not inherit from parent type (Scalar)" do
        child_field = Verse::Schema::Field.new(:data, Integer, {})
        parent_field = Verse::Schema::Field.new(:data, String, {})
        expect(child_field.inherit?(parent_field)).to be(false)
      end

      it "returns true if child type inherits from parent type (Collection)" do
        child_field = Verse::Schema::Field.new(:items, collection_of_integers, {})
        parent_field = Verse::Schema::Field.new(:items, collection_of_objects, {})
        expect(child_field.inherit?(parent_field)).to be(true)
      end

      it "returns false if child type does not inherit from parent type (Collection)" do
        child_field = Verse::Schema::Field.new(:items, collection_of_integers, {})
        parent_field = Verse::Schema::Field.new(:items, Verse::Schema::Collection.new(values: [string_scalar]), {})
        expect(child_field.inherit?(parent_field)).to be(false)
      end

      it "returns false for structurally different collection types" do
        child_field = Verse::Schema::Field.new(:array, collection_of_integers, {})
        parent_field = Verse::Schema::Field.new(:array, collection_of_integer_arrays, {})

        expect(child_field.inherit?(parent_field)).to be(false)
      end
    end

    context "when comparing union types (Array)" do
      # Helper to create fields with union types
      let(:field_int_str) { Verse::Schema::Field.new(:data, [Integer, String], {}) }
      let(:field_int) { Verse::Schema::Field.new(:data, [Integer], {}) } # Union with one type
      let(:field_obj) { Verse::Schema::Field.new(:data, Object, {}) }
      let(:field_int_str_nil) { Verse::Schema::Field.new(:data, [Integer, String, NilClass], {}) }
      let(:field_float_bool) { Verse::Schema::Field.new(:data, [Float, TrueClass, FalseClass], {}) }

      it "returns true if child union is subset of parent type (Object)" do
        # [Integer, String] <= Object should be true
        expect(field_int_str.inherit?(field_obj)).to be(true)
      end

      it "returns true if child union is subset of parent union" do
        # [Integer] <= [Integer, String] should be true
        expect(field_int.inherit?(field_int_str)).to be(true)
        # [Integer, String] <= [Integer, String, NilClass] should be true
        expect(field_int_str.inherit?(field_int_str_nil)).to be(true)
      end

      it "returns false if child union is not subset of parent type (specific type)" do
        # [Integer, String] <= Integer should be false
        parent_field_int_only = Verse::Schema::Field.new(:data, Integer, {})
        expect(field_int_str.inherit?(parent_field_int_only)).to be(false)
      end

      it "returns false if child union is not subset of parent union" do
        # [Integer, String] <= [Integer] should be false
        expect(field_int_str.inherit?(field_int)).to be(false)
        # [Integer, String] <= [Float, Boolean] should be false
        expect(field_int_str.inherit?(field_float_bool)).to be(false)
      end

      it "returns true for identical union types" do
        field_int_str_dup = Verse::Schema::Field.new(:data, [Integer, String], {})
        expect(field_int_str.inherit?(field_int_str_dup)).to be(true)
      end
    end

    context "when comparing Schema types with raw Classes" do
      let(:field_scalar_int) { Verse::Schema::Field.new(:data, Verse::Schema::Scalar.new(values: [Integer]), {}) }
      let(:field_scalar_int_str) { Verse::Schema::Field.new(:data, Verse::Schema::Scalar.new(values: [Integer, String]), {}) }
      let(:field_raw_int) { Verse::Schema::Field.new(:data, Integer, {}) }
      let(:field_raw_obj) { Verse::Schema::Field.new(:data, Object, {}) }
      let(:field_raw_str) { Verse::Schema::Field.new(:data, String, {}) }
      let(:field_union_scalar_int) { Verse::Schema::Field.new(:data, [Verse::Schema::Scalar.new(values: [Integer])], {}) } # Union containing Scalar

      it "returns true when Scalar's type matches raw Class" do
        # Scalar<Integer> <= Integer should be true
        expect(field_scalar_int.inherit?(field_raw_int)).to be(true)
      end

      it "returns true when raw Class matches Scalar's type" do
        # Integer <= Scalar<Integer> should be true
        expect(field_raw_int.inherit?(field_scalar_int)).to be(true)
      end

       it "returns true when Scalar's type inherits from raw Class" do
        # Scalar<Integer> <= Object should be true
        expect(field_scalar_int.inherit?(field_raw_obj)).to be(true)
      end

      it "returns true when raw Class inherits from Scalar's type" do
         # Integer <= Scalar<Object> should be true
         field_scalar_obj = Verse::Schema::Field.new(:data, Verse::Schema::Scalar.new(values: [Object]), {})
         expect(field_raw_int.inherit?(field_scalar_obj)).to be(true)
      end

      it "returns false when types mismatch (Scalar vs Class)" do
        # Scalar<Integer> <= String should be false
        expect(field_scalar_int.inherit?(field_raw_str)).to be(false)
        # Integer <= Scalar<String> should be false
        field_scalar_str = Verse::Schema::Field.new(:data, Verse::Schema::Scalar.new(values: [String]), {})
        expect(field_raw_int.inherit?(field_scalar_str)).to be(false)
      end

      it "handles union containing Scalar vs raw Class" do
         # [Scalar<Integer>] <= Integer should be true (matches the user's error case)
         expect(field_union_scalar_int.inherit?(field_raw_int)).to be(true)
         # Integer <= [Scalar<Integer>] should be true
         expect(field_raw_int.inherit?(field_union_scalar_int)).to be(true)
         # [Scalar<Integer>] <= String should be false
         expect(field_union_scalar_int.inherit?(field_raw_str)).to be(false)
      end

      it "handles Scalar containing union vs raw Class" do
         # Scalar<Integer|String> <= Integer should be false (Integer is not a supertype of String)
         expect(field_scalar_int_str.inherit?(field_raw_int)).to be(false)
         # Scalar<Integer|String> <= Object should be true
         expect(field_scalar_int_str.inherit?(field_raw_obj)).to be(true)
         # Integer <= Scalar<Integer|String> should be true
         expect(field_raw_int.inherit?(field_scalar_int_str)).to be(true)
      end
    end
  end
end

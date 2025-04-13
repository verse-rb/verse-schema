# frozen_string_literal: true

require_relative "../../spec_helper"

RSpec.describe Verse::Schema::Scalar do
  let(:integer_schema) { Verse::Schema::Scalar.new(values: [Integer]) }
  let(:string_or_symbol_schema) { Verse::Schema::Scalar.new(values: [String, Symbol]) }

  describe "#initialize" do
    it "initializes with values" do
      schema = Verse::Schema::Scalar.new(values: [String])
      expect(schema.values).to eq([String])
      expect(schema.post_processors).to be_nil
    end

    it "initializes with post_processors" do
      pp = Verse::Schema::PostProcessor.new { |v| v }
      schema = Verse::Schema::Scalar.new(values: [Integer], post_processors: pp)
      expect(schema.values).to eq([Integer])
      expect(schema.post_processors).to eq(pp)
    end
  end

  describe "#validate" do
    context "with single allowed type (Integer)" do
      it "succeeds for correct type" do
        result = integer_schema.validate(123)
        expect(result.success?).to be true
        expect(result.value).to eq(123)
        expect(result.errors).to be_empty
      end

      it "succeeds with coercion" do
        result = integer_schema.validate("456")
        expect(result.success?).to be true
        expect(result.value).to eq(456)
        expect(result.errors).to be_empty
      end

      it "fails for incorrect type" do
        result = integer_schema.validate("hello")
        expect(result.success?).to be false
        expect(result.value).to be_nil
        expect(result.errors).to eq({ nil => ["must be an integer"] })
      end

      it "fails for nil" do
        result = integer_schema.validate(nil)
        expect(result.success?).to be false
        expect(result.value).to be_nil
        expect(result.errors).to eq({ nil => ["must be an integer"] })
      end
    end

    context "with multiple allowed types (String, Symbol)" do
      it "succeeds for String" do
        result = string_or_symbol_schema.validate("hello")
        expect(result.success?).to be true
        expect(result.value).to eq("hello")
        expect(result.errors).to be_empty
      end

      it "succeeds for Symbol" do
        result = string_or_symbol_schema.validate(:world)
        expect(result.success?).to be true
        expect(result.value).to eq(:world)
        expect(result.errors).to be_empty
      end

      it "fails for incorrect type" do
        result = string_or_symbol_schema.validate(nil)
        expect(result.success?).to be false
        expect(result.value).to be_nil
        expect(result.errors).to eq({ nil => ["must be a symbol"] })
      end
    end

    context "with error_builder" do
      it "uses provided ErrorBuilder" do
        error_builder = Verse::Schema::ErrorBuilder.new("root")
        result = integer_schema.validate("abc", error_builder: error_builder)
        expect(result.success?).to be false
        expect(result.errors).to eq({ root: ["must be an integer"] })
      end

      it "uses provided path string for ErrorBuilder" do
        result = integer_schema.validate("abc", error_builder: "custom_path")
        expect(result.success?).to be false
        expect(result.errors).to eq({ custom_path: ["must be an integer"] })
      end
    end

    context "with post_processors" do
      it "applies post_processor on success" do
        schema = Verse::Schema::Scalar.new(values: [Integer])
        schema.transform { |v| v + 1 }

        result = schema.validate(10)
        expect(result.success?).to be true
        expect(result.value).to eq(11)
      end

      it "does not apply post_processor on failure" do
        processor_called = false
        schema = Verse::Schema::Scalar.new(values: [Integer])
        schema.transform { |_v| processor_called = true; _v + 1 }

        result = schema.validate("abc")
        expect(result.success?).to be false
        expect(processor_called).to be false
      end
    end
  end

  describe "#dup" do
    it "creates a new Scalar instance with duplicated values and post_processors" do
      pp = Verse::Schema::PostProcessor.new { |v| v + 1 }
      original = Verse::Schema::Scalar.new(values: [Integer, String], post_processors: pp)
      duplicate = original.dup

      expect(duplicate).to be_a(Verse::Schema::Scalar)
      expect(duplicate).not_to be(original)
      expect(duplicate.values).to eq([Integer, String])
      expect(duplicate.values).not_to be(original.values)
      expect(duplicate.post_processors).not_to be(original.post_processors)
      expect(duplicate.post_processors).to be_a(Verse::Schema::PostProcessor)

      # Check if post_processor logic is duplicated
      expect(duplicate.validate(10).value).to eq(11)
    end
  end

  describe "#inherit?" do
    let(:scalar_int) { Verse::Schema::Scalar.new(values: [Integer]) }
    let(:scalar_num) { Verse::Schema::Scalar.new(values: [Numeric]) }
    let(:scalar_int_str) { Verse::Schema::Scalar.new(values: [Integer, String]) }
    let(:scalar_str) { Verse::Schema::Scalar.new(values: [String]) }
    let(:collection_int) { Verse::Schema::Collection.new(values: [Integer]) }

    it "returns true if values are a subset" do
      expect(scalar_int.inherit?(scalar_num)).to be true # Integer is a Numeric
      expect(scalar_int_str.inherit?(scalar_num)).to be false # String is not Numeric
      expect(scalar_int_str.inherit?(scalar_int)).to be true
      expect(scalar_int_str.inherit?(scalar_str)).to be true
    end

    it "returns false if values are not a subset" do
      expect(scalar_num.inherit?(scalar_int)).to be false
      expect(scalar_str.inherit?(scalar_int)).to be false
    end

    it "returns false for different schema types" do
      expect(scalar_int.inherit?(collection_int)).to be false
    end

    it "returns true for same schema" do
      expect(scalar_int.inherit?(scalar_int)).to be true
    end
  end

  describe "comparison operators" do
    let(:scalar_int) { Verse::Schema::Scalar.new(values: [Integer]) }
    let(:scalar_int_dup) { Verse::Schema::Scalar.new(values: [Integer]) }
    let(:scalar_num) { Verse::Schema::Scalar.new(values: [Numeric]) }
    let(:scalar_str) { Verse::Schema::Scalar.new(values: [String]) }

    describe "#<=" do
      it { expect(scalar_int <= scalar_num).to be true }
      it { expect(scalar_int <= scalar_int_dup).to be true }
      it { expect(scalar_num <= scalar_int).to be false }
      it { expect(scalar_str <= scalar_int).to be false }
    end

    describe "#<" do
      it { expect(scalar_int < scalar_num).to be true }
      it { expect(scalar_int < scalar_int_dup).to be false } # Not strictly less
      it { expect(scalar_num < scalar_int).to be false }
      it { expect(scalar_str < scalar_int).to be false }
    end

    describe "#>" do
      it { expect(scalar_num > scalar_int).to be true }
      it { expect(scalar_int > scalar_num).to be false }
      it { expect(scalar_int > scalar_int_dup).to be false } # Not strictly greater
      it { expect(scalar_int > scalar_str).to be false }
    end
  end

  describe "#+" do
    let(:scalar_int) { Verse::Schema::Scalar.new(values: [Integer]) }
    let(:scalar_str) { Verse::Schema::Scalar.new(values: [String]) }
    let(:scalar_sym) { Verse::Schema::Scalar.new(values: [Symbol]) }
    let(:collection_int) { Verse::Schema::Collection.new(values: [Integer]) }

    it "combines values from two scalar schemas" do
      combined = scalar_int + scalar_str
      expect(combined).to be_a(Verse::Schema::Scalar)
      expect(combined.values).to contain_exactly(Integer, String)
    end

    it "combines values uniquely" do
      combined = scalar_int + scalar_int
      expect(combined.values).to eq([Integer])

      combined2 = scalar_int + Verse::Schema::Scalar.new(values: [Integer, String])
      expect(combined2.values).to contain_exactly(Integer, String)
    end

    it "combines post_processors" do
      pp1 = Verse::Schema::PostProcessor.new { |v| v + 1 }
      pp2 = Verse::Schema::PostProcessor.new { |v| v * 2 }

      schema1 = Verse::Schema::Scalar.new(values: [Integer], post_processors: pp1)
      schema2 = Verse::Schema::Scalar.new(values: [Integer], post_processors: pp2)

      combined = schema1 + schema2
      # pp1 runs first, then pp2
      expect(combined.validate(10).value).to eq(22) # (10 + 1) * 2
    end

    it "raises ArgumentError if adding non-scalar schema" do
      expect { scalar_int + collection_int }.to raise_error(ArgumentError, "aggregate must be a scalar")
    end
  end

  describe "#dataclass_schema" do
    let(:nested_struct_schema) do
      Verse::Schema.define do
        field(:value, Integer)
      end
    end
    let(:scalar_with_struct) { Verse::Schema::Scalar.new(values: [String, nested_struct_schema]) }
    let(:scalar_int) { Verse::Schema::Scalar.new(values: [Integer]) }

    before do
      # Mock dataclass_schema for nested struct if needed, assuming it exists and works
      allow(nested_struct_schema).to receive(:dataclass_schema).and_return(
        Verse::Schema.define { field(:value, Integer) } # Simplified mock return
      )
    end

    it "returns a duplicated schema" do
      dc_schema = scalar_int.dataclass_schema
      expect(dc_schema).to be_a(Verse::Schema::Scalar)
      expect(dc_schema).not_to be(scalar_int)
      expect(dc_schema.values).to eq(scalar_int.values)
    end

    it "calls dataclass_schema on nested Base schemas within values array" do
      expect(nested_struct_schema).to receive(:dataclass_schema).once
      dc_schema = scalar_with_struct.dataclass_schema
      expect(dc_schema.values[0]).to eq(String)
      # Check if the second value is the result of the mocked call
      expect(dc_schema.values[1]).to be_a(Verse::Schema::Struct) # Based on mock return
    end

    it "memoizes the result" do
      expect(scalar_int).to receive(:dup).once.and_call_original
      scalar_int.dataclass_schema
      scalar_int.dataclass_schema # Call again
    end

    # Add case if values is a single Base schema (though less common for Scalar)
    it "calls dataclass_schema if values is a single Base schema" do
      single_nested_scalar = Verse::Schema::Scalar.new(values: nested_struct_schema)
      expect(nested_struct_schema).to receive(:dataclass_schema).once
      dc_schema = single_nested_scalar.dataclass_schema
      expect(dc_schema.values).to be_a(Verse::Schema::Struct) # Based on mock return
    end
  end
end

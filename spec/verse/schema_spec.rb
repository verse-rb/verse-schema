# frozen_string_literal: true

require_relative "./examples"

RSpec.describe Verse::Schema do
  it "has a version number" do
    expect(Verse::Schema::VERSION).not_to be nil
  end

  context "Schema Cases" do
    context "SIMPLE_SCHEMA" do
      it "validates" do
        result = Examples::SIMPLE_SCHEMA.validate({
          "name" => "John Doe",
          age: "30" # Auto-coalesce
        })
        expect(result.errors).to eq({})
        expect(result.fail?).to be(false)
        expect(result.value).to eq({
          name: "John Doe",
          age: 30
        })
      end

      it "fails with complete errors list" do
        result = Examples::SIMPLE_SCHEMA.validate({})
        expect(result.success?).to be(false)
        expect(result.errors).to eq({
          age: ["is required"],
          name: ["is required"]
        })
      end

      it "fails on rules" do
        result = Examples::SIMPLE_SCHEMA.validate({
          "age" => 17,
          "name" => "Tony"
        })
        expect(result.success?).to be(false)
        expect(result.errors).to eq({
          age: ["must be 18 or older"]
        })
      end

    end

    context "OPTIONAL_FIELD_SCHEMA" do
      it "validates" do
        result = Examples::OPTIONAL_FIELD_SCHEMA.validate({
          "name" => "John Doe"
        })
        expect(result.errors).to eq({})
        expect(result.fail?).to be(false)
        expect(result.value).to eq({
          name: "John Doe"
        })
      end

      it "stills fails if rule is invalid on optional field" do
        result = Examples::OPTIONAL_FIELD_SCHEMA.validate({
          "name" => "John Doe",
          "age" => 17
        })
        expect(result.success?).to be(false)
        expect(result.errors).to eq({
          age: ["must be 18 or older"]
        })
      end

      it "fails with complete errors list" do
        result = Examples::OPTIONAL_FIELD_SCHEMA.validate({})
        expect(result.success?).to be(false)
        expect(result.errors).to eq({name: ["is required"]})
      end
    end

    context "NESTED_SCHEMA" do
      it "validates" do
        result = Examples::NESTED_SCHEMA.validate({
          "data" => {
            "name" => "John Doe",
            "age" => 30
          }
        })
        expect(result.errors).to eq({})
        expect(result.fail?).to be(false)
        expect(result.value).to eq({
          data: {
            name: "John Doe",
            age: 30
          }
        })
      end

      it "fails with complete errors list" do
        result = Examples::NESTED_SCHEMA.validate({})
        expect(result.success?).to be(false)
        expect(result.errors).to eq({data: ["is required"]})
      end

      it "show proper keys on failure" do
        result = Examples::NESTED_SCHEMA.validate({
          "data" => {
            "age" => 17
          }
        })
        expect(result.success?).to be(false)
        expect(result.errors).to eq({
          "data.age": ["must be 18 or older"],
          "data.name": ["is required"]
        })
      end
    end
  end
end

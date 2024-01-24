# frozen_string_literal: true

require_relative "./examples"

RSpec.describe Verse::Schema do
  it "has a version number" do
    expect(Verse::Schema::VERSION).not_to be nil
  end

  context "Schema Cases" do
    context "SIMPLE_SCHEMA" do
      it "validates" do
        result = Examples::SIMPLE_SCHEMA.validate(
          {
            "name" => "John Doe",
            age: "30" # Auto-coalesce
          }
        )
        expect(result.errors).to eq({})
        expect(result.fail?).to be(false)
        expect(result.value).to eq(
          {
            name: "John Doe",
            age: 30
          }
        )
      end

      it "fails with complete errors list" do
        result = Examples::SIMPLE_SCHEMA.validate({})
        expect(result.success?).to be(false)
        expect(result.errors).to eq(
          {
            age: ["is required"],
            name: ["is required"]
          }
        )
      end

      it "fails on rules" do
        result = Examples::SIMPLE_SCHEMA.validate(
          {
            "age" => 17,
            "name" => "Tony"
          }
        )
        expect(result.success?).to be(false)
        expect(result.errors).to eq(
          {
            age: ["must be 18 or older"]
          }
        )
      end
    end

    context "FILLED_ONLY_SCHEMA" do
      it "validates" do
        result = Examples::FILLED_ONLY_SCHEMA.validate(
          {
            "field" => :some_value
          }
        )
        expect(result.errors).to eq({})
        expect(result.fail?).to be(false)
        expect(result.value).to eq(
          {
            field: :some_value
          }
        )
      end

      it "fails with complete errors list" do
        result = Examples::FILLED_ONLY_SCHEMA.validate({})
        expect(result.success?).to be(false)
        expect(result.errors).to eq(
          {
            field: ["is required"]
          }
        )
      end

      it "fails on rules" do
        result = Examples::FILLED_ONLY_SCHEMA.validate(
          {
            "field" => nil
          }
        )
        expect(result.success?).to be(false)
        expect(result.errors).to eq(
          {
            field: ["must be filled"]
          }
        )
      end

      it "fails on rules (empty string)" do
        result = Examples::FILLED_ONLY_SCHEMA.validate(
          {
            "field" => ""
          }
        )
        expect(result.success?).to be(false)
        expect(result.errors).to eq(
          {
            field: ["must be filled"]
          }
        )
      end

      it "fails on rules (empty array)" do
        result = Examples::FILLED_ONLY_SCHEMA.validate(
          {
            "field" => []
          }
        )
        expect(result.success?).to be(false)
        expect(result.errors).to eq(
          {
            field: ["must be filled"]
          }
        )
      end

      it "fails on rules (empty hash)" do
        result = Examples::FILLED_ONLY_SCHEMA.validate(
          {
            "field" => {}
          }
        )
        expect(result.success?).to be(false)
        expect(result.errors).to eq(
          {
            field: ["must be filled"]
          }
        )
      end

    end

    context "OPTIONAL_FIELD_SCHEMA" do
      it "validates" do
        result = Examples::OPTIONAL_FIELD_SCHEMA.validate(
          {
            "name" => "John Doe"
          }
        )
        expect(result.errors).to eq({})
        expect(result.fail?).to be(false)
        expect(result.value).to eq(
          {
            name: "John Doe"
          }
        )
      end

      it "stills fails if rule is invalid on optional field" do
        result = Examples::OPTIONAL_FIELD_SCHEMA.validate(
          {
            "name" => "John Doe",
            "age" => 17
          }
        )
        expect(result.success?).to be(false)
        expect(result.errors).to eq(
          {
            age: ["must be 18 or older"]
          }
        )
      end

      it "fails with complete errors list" do
        result = Examples::OPTIONAL_FIELD_SCHEMA.validate({})
        expect(result.success?).to be(false)
        expect(result.errors).to eq({ name: ["is required"] })
      end
    end

    context "NESTED_SCHEMA" do
      it "validates" do
        result = Examples::NESTED_SCHEMA.validate(
          {
            "data" => {
              "name" => "John Doe",
              "age" => 30
            }
          }
        )
        expect(result.errors).to eq({})
        expect(result.fail?).to be(false)
        expect(result.value).to eq(
          {
            data: {
              name: "John Doe",
              age: 30
            }
          }
        )
      end

      it "fails with complete errors list" do
        result = Examples::NESTED_SCHEMA.validate({})
        expect(result.success?).to be(false)
        expect(result.errors).to eq({ data: ["is required"] })
      end

      it "show proper keys on failure" do
        result = Examples::NESTED_SCHEMA.validate(
          {
            "data" => {
              "age" => 17
            }
          }
        )
        expect(result.success?).to be(false)
        expect(result.errors).to eq(
          {
            "data.age": ["must be 18 or older"],
            "data.name": ["is required"]
          }
        )
      end
    end

    context "ARRAY_SCHEMA" do
      it "validates" do
        result = Examples::ARRAY_SCHEMA.validate(
          {
            "data" => [
              {
                "name" => "John Doe",
                "age" => 30
              },
              {
                "name" => "Jane Doe",
                "age" => 20
              }
            ]
          }
        )
        expect(result.errors).to eq({})
        expect(result.fail?).to be(false)
        expect(result.value).to eq(
          {
            data: [
              {
                name: "John Doe",
                age: 30
              },
              {
                name: "Jane Doe",
                age: 20
              }
            ]
          }
        )
      end

      it "fails with complete errors list" do
        result = Examples::ARRAY_SCHEMA.validate({})
        expect(result.success?).to be(false)
        expect(result.errors).to eq({ data: ["is required"] })
      end

      it "shows proper keys on failure" do
        result = Examples::ARRAY_SCHEMA.validate(
          {
            "data" => [
              {
                "age" => 30
              },
              {
                "name" => "Jane Doe",
                "age" => 17
              }
            ]
          }
        )
        expect(result.success?).to be(false)
        expect(result.errors).to eq(
          {
            "data.0.name": ["is required"],
            "data.1.age": ["must be 18 or older"]
          }
        )
      end

      it "shows proper keys on failure (non correct type)" do
        result = Examples::ARRAY_SCHEMA.validate(
          {
            "data" => [
              {
                "name" => "John Doe",
                "age" => 30
              },
              "incorrect type"
            ]
          }
        )
        expect(result.success?).to be(false)
        expect(result.errors).to eq({
                                      "data.1": ["hash expected"]
                                    })
      end
    end

    context "ARRAY_SCHEMA_WITH_BLOCK" do
      it "validates" do
        result = Examples::ARRAY_SCHEMA_WITH_BLOCK.validate(
          {
            "data" => [
              {
                "name" => "John Doe",
                "age" => 30
              },
              {
                "name" => "Jane Doe",
                "age" => "20"
              }
            ]
          }
        )
        expect(result.errors).to eq({})
        expect(result.fail?).to be(false)
        expect(result.value).to eq(
          {
            data: [
              {
                name: "John Doe",
                age: 30
              },
              {
                name: "Jane Doe",
                age: 20
              }
            ]
          }
        )
      end

      it "fails with complete errors list" do
        result = Examples::ARRAY_SCHEMA_WITH_BLOCK.validate({})
        expect(result.success?).to be(false)
        expect(result.errors).to eq({ data: ["is required"] })
      end

      it "shows proper keys on failure" do
        result = Examples::ARRAY_SCHEMA_WITH_BLOCK.validate(
          {
            "data" => [
              {
                "name" => "",
                "age" => 30
              },
              {
                "name" => "Jane Doe",
                "age" => 17
              }
            ]
          }
        )
        expect(result.success?).to be(false)
        expect(result.errors).to eq(
          {
            "data.0.name": ["must be filled"],
            "data.1.age": ["must be 18 or older"]
          }
        )
      end
    end

    context "MULTIPLE_FIELDS_RULE" do
      it "validates" do
        result = Examples::MULTIPLE_FIELDS_RULE.validate(
          {
            "name" => "John Doe",
            "age" => 30
          }
        )
        expect(result.errors).to eq({})
        expect(result.fail?).to be(false)
        expect(result.value).to eq(
          {
            name: "John Doe",
            age: 30
          }
        )
      end

      it "fails with complete errors list" do
        result = Examples::MULTIPLE_FIELDS_RULE.validate({})
        expect(result.success?).to be(false)
        expect(result.errors).to eq(
          {
            age: ["is required"],
            name: ["is required"]
          }
        )
      end

      it "shows proper keys on failure" do
        result = Examples::MULTIPLE_FIELDS_RULE.validate(
          {
            "name" => "John Doe",
            "age" => 17
          }
        )
        expect(result.success?).to be(false)
        expect(result.errors).to eq(
          {
            age: ["Age must be 18 and name must NOT be John"],
            name: ["Age must be 18 and name must NOT be John"]
          }
        )
      end
    end

    context "MULTIPLE_TYPES_FIELD" do
      it "validates" do
        result = Examples::MULTIPLE_TYPES_FIELD.validate(
          {
            "title" => "Hello",
            "content" => "World"
          }
        )
        expect(result.errors).to eq({})
        expect(result.fail?).to be(false)
        expect(result.value).to eq({
                                     title: "Hello",
                                     content: "World"
                                   })
      end

      it "validates (subhash)" do
        result = Examples::MULTIPLE_TYPES_FIELD.validate(
          {
            "title" => "Hello",
            "content" => {
              "content" => "World",
              "created_at" => "2011-10-05T14:48:00.000Z"
            }
          }
        )
        expect(result.errors).to eq({})
        expect(result.fail?).to be(false)
        expect(result.value).to eq(
          {
            title: "Hello",
            content: {
              content: "World",
              created_at: Time.parse("2011-10-05T14:48:00.000Z")
            }
          }
        )
      end
    end

    context "OPEN_HASH" do
      it "validates" do
        result = Examples::OPEN_HASH.validate({
                                                "name" => "John Doe",
                                                "age" => 30,
                                                "unknown" => "value"
                                              })
        expect(result.errors).to eq({})
        expect(result.fail?).to be(false)
        expect(result.value).to eq({
                                     name: "John Doe",
                                     age: 30,
                                     unknown: "value"
                                   })
      end

      it "fails with complete errors list" do
        result = Examples::OPEN_HASH.validate({
                                                "age" => 21
                                              })
        expect(result.success?).to be(false)
        expect(result.errors).to eq({
                                      name: ["is required"]
                                    })
      end
    end

    context "RULE_IN" do
      it "validates" do
        result = Examples::RULE_IN.validate(
          {
            "provider" => "facebook"
          }
        )
        expect(result.errors).to eq({})
        expect(result.fail?).to be(false)
        expect(result.value).to eq(
          {
            provider: "facebook"
          }
        )
      end

      it "fails with complete errors list" do
        result = Examples::RULE_IN.validate({})
        expect(result.success?).to be(false)
        expect(result.errors).to eq(
          {
            provider: ["is required"]
          }
        )
      end

      it "fails on rules" do
        result = Examples::RULE_IN.validate(
          {
            "provider" => "invalid"
          }
        )
        expect(result.success?).to be(false)
        expect(result.errors).to eq(
          {
            provider: ["must be one of facebook, google"]
          }
        )
      end
    end

    context "HASH_WITH_BLOCK" do
      it "validates" do
        result = Examples::HASH_WITH_BLOCK.validate(
          {
            "type" => "event",
            "data" => {
              "name" => "John Doe",
              "age" => 30
            }
          }
        )
        expect(result.errors).to eq({})
        expect(result.fail?).to be(false)
        expect(result.value).to eq(
          {
            type: "event",
            data: {
              name: "John Doe",
              age: 30
            }
          }
        )
      end

      it "fails with complete errors list" do
        result = Examples::HASH_WITH_BLOCK.validate({})
        expect(result.success?).to be(false)
        expect(result.errors).to eq(
          {
            type: ["is required"],
            data: ["is required"]
          }
        )
      end
    end

    context "DICTIONARY" do
      it "validates" do
        result = Examples::DICTIONARY.validate(
          {
            "dict" => {
              "key1" => 1,
              "key2" => "2"
            }
          }
        )
        expect(result.errors).to eq({})
        expect(result.fail?).to be(false)
        expect(result.value).to eq(
          {
            dict: {
              key1: 1,
              key2: 2
            }
          }
        )
      end

      it "fails if one key is invalid" do
        result = Examples::DICTIONARY.validate(
          {
            "dict" => {
              "key1" => 1,
              "key2" => "invalid"
            }
          }
        )
        expect(result.success?).to be(false)
        expect(result.errors).to eq(
          {
            "dict.key2": ["must be an integer"]
          }
        )
      end

    end

    context "EVENT_HASH" do
      it "validates" do
        result = Examples::EVENT_HASH.validate(
          {
            "type" => "event",
            "data" => {
              "name" => "John Doe",
              "age" => 30
            },
            "created_at" => "2011-10-05T14:48:00.000Z"
          }
        )
        expect(result.errors).to eq({})
        expect(result.fail?).to be(false)
        expect(result.value).to eq(
          Examples::Event.new(
            "event",
            {
              name: "John Doe",
              age: 30
            },
            Time.parse("2011-10-05T14:48:00.000Z")
          )
        )
      end

      it "fails with complete errors list" do
        result = Examples::EVENT_HASH.validate({})
        expect(result.success?).to be(false)
        expect(result.errors).to eq(
          {
            type: ["is required"],
            data: ["is required"],
            created_at: ["is required"]
          }
        )
      end
    end
  end

  context "COMPLEX_EXAMPLE" do
    it "validates" do
      result = Examples::COMPLEX_EXAMPLE.validate(
        "events" => [{
          "at" => "2011-10-05T14:48:00.000Z",
          "type" => "created",
          "provider" => "facebook",
          "data" => {
            "url" => "https://facebook.com/123",
            "name" => "John Doe",
            "age" => 30
          },
          "source" => "facebook"
        }]
      )
      expect(result.errors).to eq({})
      expect(result.fail?).to be(false)
      expect(result.value).to eq(
        events: [{
          at: Time.parse("2011-10-05T14:48:00.000Z"),
          type: :created,
          provider: "facebook",
          data: {
            url: "https://facebook.com/123",
            name: "John Doe",
            age: 30
          },
          source: "facebook"
        }]
      )
    end

    it "fails if wrong event structure" do
      # rule says that google event requires search
      result = Examples::COMPLEX_EXAMPLE.validate(
        "events" => [{
          "at" => "2011-10-05T14:48:00.000Z",
          "type" => "created",
          "provider" => "google",
          "data" => {
            "url" => "https://facebook.com/123",
            "name" => "John Doe",
            "age" => 30
          },
          "source" => "facebook"
        }]
      )
      expect(result.success?).to be(false)
      expect(result.errors).to eq(
        {
          "events.0.data": ["invalid event data structure"]
        }
      )
    end
  end

end

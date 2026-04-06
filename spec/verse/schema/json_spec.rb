# frozen_string_literal: true

require_relative "../../spec_helper"

RSpec.describe Verse::Schema::Json do
  describe ".from" do
    it "converts a simple schema to json schema" do
      schema = Verse::Schema.define do
        field(:name, String).meta(description: "The name of the user")
        field(:age, Integer)
        field(:enabled, TrueClass).default(true)
      end

      json_schema = described_class.from(schema)

      expect(json_schema).to eq({
        type: "object",
        properties: {
          name: {
            type: "string",
            description: "The name of the user"
          },
          age: {
            type: "integer"
          },
          enabled: {
            type: "boolean",
            default: true
          }
        },
        required: [:name, :age],
        additionalProperties: false
      })
    end

    it "converts a schema with meta description/desc" do
      schema = Verse::Schema.define do
        field(:title, String).meta(description: "The title of the item")
        field(:count, Integer).meta(desc: "The count of items")
      end

      json_schema = described_class.from(schema)
      expect(json_schema).to eq({
        type: "object",
        properties: {
          title: {
            type: "string",
            description: "The title of the item"
          },
          count: {
            type: "integer",
            description: "The count of items"
          }
        },
        required: [:title, :count],
        additionalProperties: false
      })
    end

    it "converts a schema with nested structs" do
      schema = Verse::Schema.define do
        field(:user) do
          field(:name, String)
          field(:email, String)
        end
      end

      json_schema = described_class.from(schema)
      user_schema = schema.fields.first.type

      expect(json_schema).to eq({
        type: "object",
        properties: {
          user: {
            "$ref": "#/$defs/Schema#{user_schema.object_id}"
          }
        },
        required: [:user],
        additionalProperties: false,
        "$defs": {
          "Schema#{user_schema.object_id}": {
            type: "object",
            properties: {
              name: { type: "string" },
              email: { type: "string" }
            },
            required: [:name, :email],
            additionalProperties: false
          }
        }
      })
    end

    it "converts a schema with collections" do
      schema = Verse::Schema.define do
        field(:tags, Array, of: String)
        field(:posts, Array) do
          field(:title, String)
          field(:content, String)
        end
      end

      json_schema = described_class.from(schema)

      posts_schema = schema.fields.find{ |f| f.name == :posts }.type.values.first

      expect(json_schema).to eq({
        type: "object",
        properties: {
          tags: {
            type: "array",
            items: {
              type: "string"
            }
          },
          posts: {
            type: "array",
            items: { "$ref": "#/$defs/Schema#{posts_schema.object_id}" }
          }
        },
        required: [:tags, :posts],
        additionalProperties: false,
        "$defs": {
          "Schema#{posts_schema.object_id}": {
            type: "object",
            properties: {
              title: { type: "string" },
              content: { type: "string" }
            },
            required: [:title, :content],
            additionalProperties: false
          }
        }
      })
    end

    it "converts a schema with a dictionary" do
      schema = Verse::Schema.define do
        field(:meta, Hash, of: String)
      end

      json_schema = described_class.from(schema)

      expect(json_schema).to eq({
        type: "object",
        properties: {
          meta: {
            type: "object",
            additionalProperties: { type: "string" }
          }
        },
        required: [:meta],
        additionalProperties: false
      })
    end

    it "converts a dictionary of array" do
      schema = Verse::Schema.define do
        field(:tags, Hash, of: Array)
      end

      json_schema = described_class.from(schema)

      expect(json_schema).to eq({
        type: "object",
        properties: {
          tags: {
            type: "object",
            additionalProperties: {
              type: "array"
            }
          }
        },
        required: [:tags],
        additionalProperties: false
      })
    end

    it "converts a recursive schema" do
      recursive_schema = Verse::Schema.define do
        field(:name, String)
        field(:children, Array, of: self).default([])
      end

      json_schema = described_class.from(recursive_schema)

      expect(json_schema).to eq({
        type: "object",
        properties: {
          name: { type: "string" },
          children: {
            type: "array",
            items: { "$ref": "#/$defs/Schema#{recursive_schema.object_id}" },
            default: []
          }
        },
        required: [:name],
        additionalProperties: false,
        "$defs": {
          "Schema#{recursive_schema.object_id}": {
            type: "object",
            properties: {
              name: { type: "string" },
              children: {
                type: "array",
                items: { "$ref": "#/$defs/Schema#{recursive_schema.object_id}" },
                default: []
              }
            },
            required: [:name],
            additionalProperties: false
          }
        }
      })
    end

    it "converts a selector schema" do
      facebook_schema = Verse::Schema.define do
        field(:url, String)
      end

      google_schema = Verse::Schema.define do
        field(:search, String)
      end

      schema = Verse::Schema.define do
        field(:type, Symbol).in?(%i[facebook google])
        field(:data, {
          facebook: facebook_schema,
          google: google_schema
        }, over: :type)
      end

      json_schema = described_class.from(schema)

      expect(json_schema).to eq({
        type: "object",
        properties: {
          type: { type: "string", enum: %w[facebook google] },
          data: { type: "object" }
        },
        required: [:type, :data],
        additionalProperties: false,
        allOf: [
          {
            if: { properties: { type: { const: "facebook" } } },
            then: {
              properties: {
                data: { "$ref": "#/$defs/Schema#{facebook_schema.object_id}" }
              }
            }
          },
          {
            if: { properties: { type: { const: "google" } } },
            then: {
              properties: {
                data: { "$ref": "#/$defs/Schema#{google_schema.object_id}" }
              }
            }
          }
        ],
        "$defs": {
          "Schema#{facebook_schema.object_id}": {
            type: "object",
            properties: {
              url: { type: "string" }
            },
            required: [:url],
            additionalProperties: false
          },
          "Schema#{google_schema.object_id}": {
            type: "object",
            properties: {
              search: { type: "string" }
            },
            required: [:search],
            additionalProperties: false
          }
        }
      })
    end

    it "converts an object schema" do
      schema = Verse::Schema.define do
        field(:config, Object)
      end

      json_schema = described_class.from(schema)
      expect(json_schema).to eq({
        type: "object",
        properties: {
          config: {}
        },
        required: [:config],
        additionalProperties: false
      })
    end

    it "converts a set schema" do
      schema = Verse::Schema.define do
        field(:items, Set)
      end

      json_schema = described_class.from(schema)
      expect(json_schema).to eq({
        type: "object",
        properties: {
          items: { type: "array" }
        },
        required: [:items],
        additionalProperties: false
      })
    end

    it "converts a hash schema" do
      schema = Verse::Schema.define do
        field(:settings, Hash)
      end

      json_schema = described_class.from(schema)
      expect(json_schema).to eq({
        type: "object",
        properties: {
          settings: { type: "object" }
        },
        required: [:settings],
        additionalProperties: false
      })
    end

    it "converts an IO/Tempfile schema" do
      schema = Verse::Schema.define do
        field(:file, IO)
        field(:tempfile, Tempfile)
      end

      json_schema = described_class.from(schema)
      expect(json_schema).to eq({
        type: "object",
        properties: {
          file: {
            type: "object",
            instanceof: "IO",
            description: "A native IO stream or file pointer"
          },
          tempfile: {
            type: "object",
            instanceof: "IO",
            description: "A native IO stream or file pointer"
          }
        },
        required: [:file, :tempfile],
        additionalProperties: false
      })
    end

    it "converts a custom schema" do
      class CustomSchemaType
        def to_json_schema
          { type: "string", pattern: "^[a-z]+$" }
        end
      end

      schema = Verse::Schema.define do
        field(:data, CustomSchemaType.new)
      end

      json_schema = described_class.from(schema)

      expect(json_schema).to eq({
        type: "object",
        properties: {
          data: {
            type: "string",
            pattern: "^[a-z]+$"
          }
        },
        required: [:data],
        additionalProperties: false
      })
    end

    it "raises an error for unknown types" do
      class UnknownType; end
      schema = Verse::Schema.define do
        field(:data, UnknownType.new)
      end

      expect {
        described_class.from(schema)
      }.to raise_error("Unknown type #{schema.fields.first.type.inspect}")
    end
  end
end

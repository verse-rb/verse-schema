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
  end
end

# frozen_string_literal: true

require_relative "../../../spec_helper"
require "json"

RSpec.describe "JSON Schema Generation", :readme do
  describe "Generating JSON Schema", :readme_section do
    it "converts a simple schema to a valid JSON schema" do
      schema = Verse::Schema.define do
        field(:name, String).meta(description: "The name of the user")
        field(:age, Integer)
      end

      json_schema = Verse::Schema::Json.from(schema)
      puts JSON.pretty_generate(json_schema)

      # The output of the `to_json` method will be a valid JSON schema hash:
      #
      # {
      #   "type": "object",
      #   "properties": {
      #     "name": {
      #       "type": "string",
      #       "description": "The name of the user"
      #     },
      #     "age": {
      #       "type": "integer"
      #     }
      #   },
      #   "required": [
      #     "name",
      #     "age"
      #   ],
      #   "additionalProperties": false
      # }
    end
  end
end

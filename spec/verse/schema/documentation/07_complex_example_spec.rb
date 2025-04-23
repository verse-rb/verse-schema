# frozen_string_literal: true

require_relative "../../../spec_helper"

RSpec.describe "Verse::Schema Documentation", :readme do
  context "Complex Example", :readme_section do
    it "demonstrates a comprehensive example" do
      # Define a complex schema that combines multiple features
      schema = Verse::Schema.define do
        # Define nested schemas
        facebook_event = define do
          field(:url, String)
          extra_fields # Allow additional fields
        end

        google_event = define do
          field(:search, String)
          extra_fields # Allow additional fields
        end

        # Define an event schema that uses the nested schemas
        event = define do
          field(:at, Time)
          field(:type, Symbol).in?(%i[created updated])
          field(:provider, String).in?(%w[facebook google])
          field(:data, [facebook_event, google_event]) # Union type
          field(:source, String)

          # Conditional validation based on provider
          rule(:data, "invalid event data structure") do |hash|
            case hash[:provider]
            when "facebook"
              facebook_event.valid?(hash[:data])
            when "google"
              google_event.valid?(hash[:data])
            else
              false
            end
          end
        end

        # The main schema field is an array of events
        field(:events, Array, of: event)
      end

      # Create a complex data structure to validate
      data = {
        events: [
          {
            at: "2023-01-01T12:00:00Z",
            type: :created,
            provider: "facebook",
            data: {
              url: "https://facebook.com/event/123",
              title: "Facebook Event" # Extra field
            },
            source: "api"
          },
          {
            at: "2023-01-02T14:30:00Z",
            type: :updated,
            provider: "google",
            data: {
              search: "conference 2023",
              location: "New York" # Extra field
            },
            source: "webhook"
          }
        ]
      }

      # Validate the complex data
      result = schema.validate(data)

      # The validation succeeds
      expect(result.success?).to be true

      # The output maintains the structure with coerced values
      expect(result.value[:events][0][:at]).to be_a(Time)
      expect(result.value[:events][1][:at]).to be_a(Time)
    end
  end

  context "Polymorphic Schema", :readme_section do
    it "demonstrates a polymorphic schema" do
      # Polymorphism without selector model can be achieved using a builder
      # virtual object which will convert the input schema to the correct
      # schema based on the type of the input.
      #
      # Here is an example on how to do:
      #
      # 1. Define the base schema for the polymorphic structure:
      base_schema = Verse::Schema.define do
        field(:type, Symbol)
      end

      # 2. Define the specific schemas for each type:
      facebook_schema = Verse::Schema.define(base_schema) do
        field(:url, String)
        field(:title, String)
      end

      google_schema = Verse::Schema.define(base_schema) do
        field(:search, String)
        field(:location, String)
      end

      # 3. Define a builder schema. The best way to do this is to use the
      # scalar type:
      builder_schema = Verse::Schema.scalar(Hash).transform do |input, error_builder|
        type = input[:type]

        if type.respond_to?(:to_sym)
          type = type.to_sym
        else
          error_builder.add(:type, "invalid type")
          stop
        end

        schema = case type
                 when :facebook
                   facebook_schema
                 when :google
                   google_schema
                 else
                   error_builder.add(:type, "invalid type")
                   stop
                 end

        # Validate the input against the selected schema
        result = schema.validate(input, error_builder:)

        result.value if result.success?
      end

      # 4. Now, you can use the builder schema as placeholder for your
      # polymorphic schema:
      schema = Verse::Schema.define do
        field(:events, Array, of: builder_schema)
      end

      # 5. Create a complex data structure to validate
      data = {
        events: [
          {
            type: "facebook",
            url: "https://facebook.com/event/123",
            title: "Facebook Event"
          },
          {
            type: "google",
            search: "conference 2023",
            location: "New York"
          }
        ]
      }

      # 6. Validate the complex data
      result = schema.validate(data)
      # The validation succeeds
      expect(result.success?).to be true
      # The output maintains the structure with coerced values
      expect(result.value[:events][0][:type]).to eq(:facebook)
      expect(result.value[:events][0][:url]).to eq("https://facebook.com/event/123")
      expect(result.value[:events][0][:title]).to eq("Facebook Event")

      expect(result.value[:events][1][:type]).to eq(:google)
      expect(result.value[:events][1][:search]).to eq("conference 2023")
      expect(result.value[:events][1][:location]).to eq("New York")

      # 6.1 Invalid data
      invalid_data = {
        events: [
          {
            type: "facebook",
            # missing required url field
            title: "Facebook Event"
          },
          {
            type: "google",
            search: "conference 2023",
            # missing required location field
          },
          {
            type: "invalid",
            url: "https://invalid.com/event/123",
            title: "Invalid Event"
          }
        ]
      }
      # Validate the invalid data
      invalid_result = schema.validate(invalid_data)
      # The validation fails
      expect(invalid_result.success?).to be false
      # The errors are collected
      expect(invalid_result.errors).to eq({
        "events.0.url": ["is required"],
        "events.1.location": ["is required"],
        "events.2.type": ["invalid type"]
      })
    end
  end
end

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
end

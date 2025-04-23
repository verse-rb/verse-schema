# frozen_string_literal: true

require_relative "../../../spec_helper"

RSpec.describe "Rules and Post Processing", :readme do
  context "Postprocessing", :readme_section do
    it "demonstrates postprocessing with transform" do
      Event = Struct.new(:type, :data, :created_at) unless defined?(Event)

      event_schema = Verse::Schema.define do
        field(:type, String)
        field(:data, Hash).transform{ |input| input.transform_keys(&:to_sym) }
        field(:created_at, Time)

        # Transform the output of this schema definition.
        transform do |input|
          Event.new(input[:type], input[:data], input[:created_at])
        end
      end

      output = event_schema.validate({
        type: "user.created",
        data: { "name" => "John" },
        created_at: "2020-01-01T00:00:00Z"
      }).value

      expect(output).to be_a(Event)
      expect(output.type).to eq("user.created")
      expect(output.data).to eq({ name: "John" })
      expect(output.created_at).to be_a(Time)
    end

    it "demonstrates chaining multiple post processors" do
      # Create a schema with multiple rules on a field
      schema = Verse::Schema.define do
        field(:age, Integer)
          .rule("must be at least 18") { |age| age >= 18 }
          .rule("must be under 100") { |age| age < 100 }
      end

      # Valid age
      result1 = schema.validate({ age: 30 })
      expect(result1.success?).to be true

      # Too young
      result2 = schema.validate({ age: 16 })
      expect(result2.success?).to be false
      expect(result2.errors).to eq({ age: ["must be at least 18"] })

      # Too old
      result3 = schema.validate({ age: 120 })
      expect(result3.success?).to be false
      expect(result3.errors).to eq({ age: ["must be under 100"] })
    end

    it "demonstrates rule with error_builder parameter" do
      # Create a schema with a rule that uses the error_builder
      schema = Verse::Schema.define do
        field(:data, Hash).rule("must contain required keys") do |data, error_builder|
          valid = true

          # Check for required keys
          %w[name email].each do |key|
            unless data.key?(key.to_sym) || data.key?(key)
              error_builder.add(:data, "missing required key: #{key}")
              valid = false
            end
          end

          valid
        end
      end

      # Valid data
      result1 = schema.validate({ data: { name: "John", email: "john@example.com" } })
      expect(result1.success?).to be true

      # Missing name
      result2 = schema.validate({ data: { email: "john@example.com" } })
      expect(result2.success?).to be false
      expect(result2.errors).to eq({ data: ["missing required key: name", "must contain required keys"] })

      # Missing email
      result3 = schema.validate({ data: { name: "John" } })
      expect(result3.success?).to be false
      expect(result3.errors).to eq({ data: ["missing required key: email", "must contain required keys"] })
    end
  end

  context "Rules", :readme_section do
    it "demonstrates per schema rules" do
      # Multiple fields rule
      multiple_field_rule_schema = Verse::Schema.define do
        field(:name, String)
        field(:age, Integer)

        rule(%i[age name], "age must be 18 and name must NOT be John") do |schema|
          schema[:age] >= 18 && schema[:name] != "John"
        end
      end

      # Valid case
      result1 = multiple_field_rule_schema.validate({
        name: "Jane",
        age: 20
      })
      expect(result1.success?).to be true

      # Invalid case - rule violation
      result2 = multiple_field_rule_schema.validate({
        name: "John",
        age: 20
      })
      expect(result2.success?).to be false
      expect(result2.errors).to eq({ age: ["age must be 18 and name must NOT be John"], name: ["age must be 18 and name must NOT be John"] })
    end

    it "demonstrates reusable rules defined with Verse::Schema.rule" do
      # Define a reusable rule object
      is_positive = Verse::Schema.rule("must be positive") { |value| value > 0 }

      # Define another reusable rule
      is_even = Verse::Schema.rule("must be even", &:even?)

      # Create a schema that uses the reusable rules
      schema = Verse::Schema.define do
        field(:quantity, Integer)
          .rule(is_positive)
          .rule(is_even)

        field(:price, Float)
          .rule(is_positive) # Reuse the same rule
      end

      # Valid case
      result1 = schema.validate({ quantity: 10, price: 9.99 })
      expect(result1.success?).to be true

      # Invalid quantity (negative)
      result2 = schema.validate({ quantity: -2, price: 9.99 })
      expect(result2.success?).to be false
      expect(result2.errors).to eq({ quantity: ["must be positive"] })

      # Invalid quantity (odd)
      result3 = schema.validate({ quantity: 5, price: 9.99 })
      expect(result3.success?).to be false
      expect(result3.errors).to eq({ quantity: ["must be even"] })

      # Invalid price (zero)
      result4 = schema.validate({ quantity: 10, price: 0.0 })
      expect(result4.success?).to be false
      expect(result4.errors).to eq({ price: ["must be positive"] })
    end
  end

  context "Locals Variables", :readme_section do
    it "demonstrates locals variables" do
      schema = Verse::Schema.define do
        field(:age, Integer).rule("must be greater than %<min_age>s") { |age|
          age > locals[:min_age]
        }
      end

      # Valid case
      result1 = schema.validate({ age: 22 }, locals: { min_age: 21 })
      expect(result1.success?).to be true

      # Invalid case
      result2 = schema.validate({ age: 18 }, locals: { min_age: 21 })
      expect(result2.success?).to be false
      expect(result2.errors).to eq({ age: ["must be greater than 21"] })
    end
  end
end

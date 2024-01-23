# frozen_string_literal: true

module Examples
  MUST_BE_MAJOR = Verse::Schema.rule("must be 18 or older") do |value|
    value >= 18
  end

  # simple schema with a rule
  SIMPLE_SCHEMA = Verse::Schema.define do
    field(:name, String).label("Name").description("The name of the person")
    field(:age, Integer).rule(MUST_BE_MAJOR)
  end

  # optional field
  OPTIONAL_FIELD_SCHEMA = Verse::Schema.define do
    field(:name, String).label("Name").description("The name of the person")
    field?(:age, Integer).rule("must be 18 or older"){ |age| age >= 18 }
  end

  # nested schema
  NESTED_SCHEMA = Verse::Schema.define do
    # Hash of simple schema
    field(:data, SIMPLE_SCHEMA)
  end

  # Array schema with ref
  ARRAY_SCHEMA = Verse::Schema.define do
    # Array of simple schema
    field(:data, Array, of: SIMPLE_SCHEMA)
  end

  # Array schema with block
  ARRAY_SCHEMA_WITH_BLOCK = Verse::Schema.define do
    field(:data, Array) do
      field(:name, String).filled
      field(:age, Integer).rule(MUST_BE_MAJOR)
    end
  end

  # multiple fields rule
  MULTIPLE_FIELDS_RULE = Verse::Schema.define do
    field(:name, String)
    field(:age, Integer)

    rule(%i[age name], "Age must be 18 and name must be John") do |schema|
      schema[:age] >= 18 && schema[:name] != "John"
    end
  end
end

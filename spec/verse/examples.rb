# frozen_string_literal: true

module Examples
  MUST_BE_MAJOR = Verse::Schema.rule("must be 18 or older") do |value|
    value >= 18
  end

  # simple schema with a rule
  SIMPLE_SCHEMA = Verse::Schema.define do
    field(:name, String).meta(label: "Name", description: "The name of the person").filled
    field(:age, Integer).rule(MUST_BE_MAJOR)
  end

  FILLED_ONLY_SCHEMA = Verse::Schema.define do
    # Use object for any type
    field(:field, Object).filled
  end

  # optional field
  OPTIONAL_FIELD_SCHEMA = Verse::Schema.define do
    field(:name, String).meta(label: "Name", description: "The name of the person")
    field?(:age, Integer).rule("must be 18 or older") { |age| age >= 18 }
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

    rule(%i[age name], "Age must be 18 and name must NOT be John") do |schema|
      schema[:age] >= 18 && schema[:name] != "John"
    end
  end

  MULTIPLE_TYPES_FIELD = Verse::Schema.define do
    content_hash = Verse::Schema.define do
      field(:content, String).filled
      field :created_at, Time
    end

    field :title, String
    field(:content, [String, content_hash]).filled
  end

  RULE_IN = Verse::Schema.define do
    field(:provider, String).in?(%w[facebook google])
  end

  OPEN_HASH = Verse::Schema.define do
    field(:name, String)

    extra_fields
  end

  HASH_WITH_BLOCK = Verse::Schema.define do
    field(:type, String)

    field(:data, Hash) do
      field(:name, String).filled
      field(:age, Integer).rule(MUST_BE_MAJOR)
    end
  end

  DICTIONARY = Verse::Schema.define do
    field(:dict, Hash, of: Integer)
  end

  # Transformers setup
  Event = Struct.new(:type, :data, :created_at)

  EVENT_HASH = Verse::Schema.define do
    field(:type, String)
    field(:data, Hash).transform { |input| input.transform_keys(&:to_sym) }
    field(:created_at, Time)

    transform do |input|
      Event.new(input[:type], input[:data], input[:created_at])
    end
  end

  DEFAULT_VALUE = Verse::Schema.define do
    # block default
    field(:type, String).default { "unknown" }
    # param default
    field(:ordered, TrueClass).default(false)
    # reset default
    field(:has_no_default, String).default("def").required # required after default remove defaut value
  end

  # Complex example using almost everything:
  COMPLEX_EXAMPLE = Verse::Schema.define do
    facebook_event = define do
      field(:url, String).filled

      extra_fields
    end

    google_event = define do
      field(:search, String).filled

      extra_fields
    end

    event = define do
      field(:at, Time)
      field(:type, Symbol).in?(%i[created updated])
      field(:provider, String).in?(%w[facebook google])

      field(:data, [facebook_event, google_event])
      field(:source, String).filled

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

    field(:events, Array, of: event)
  end
end

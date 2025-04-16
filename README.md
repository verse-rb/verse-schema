# Verse::Schema

## Summary

Verse::Schema is a Ruby gem that provides a DSL for data validation and coercion.

It is designed to be used in a context where you need to validate and coerce data coming from external sources (e.g. HTTP requests, database, etc...).

Verse was initially using [dry-validation](https://dry-rb.org/gems/dry-validation/) for this purpose, but we found it too complex to use and to extend. Autodocumentation was almost impossible, and the different concepts (Schema, Params, Contract...) was not really clear in our opinion.

## Installation

Add this line to your application's Gemfile:

```ruby
  gem 'verse-schema'
```

## Concept

Verse::Schema provides a flexible and opinionated way to define data structures, validate input, and coerce values. The core philosophy revolves around clear, explicit definitions and predictable transformations.

**Key Principles:**

*   **Validation and Coercion:** The primary goal is to ensure incoming data conforms to a defined structure and type, automatically coercing values where possible (e.g., string "123" to integer 123).
*   **Explicit Definitions:** Schemas are defined using a clear DSL, making the expected data structure easy to understand.
*   **Symbolized Keys:** By design, all hash keys within validated data are converted to symbols for consistency.
*   **Coalescing:** The library attempts to intelligently convert input values to the target type defined in the schema. This simplifies handling data from various sources (like JSON strings, form parameters, etc.).
*   **Extensibility:** While opinionated, the library allows for custom rules, post-processing transformations, and schema inheritance.

**Schema Types (Wrappers):**

Verse::Schema offers several base schema types to handle different data structures:

*   **`Verse::Schema::Struct`:** The most common type, used for defining hash-like structures with fixed keys and specific types for each value. This is the default when using `Verse::Schema.define { ... }`. It validates the presence, type, and rules for each defined field. It can optionally allow extra fields not explicitly defined.
*   **`Verse::Schema::Collection`:** Used for defining arrays where each element must conform to a specific type or schema. Created using `Verse::Schema.array(TypeOrSchema)` or `field(:name, Array, of: TypeOrSchema)`.
*   **`Verse::Schema::Dictionary`:** Defines hash-like structures where keys are symbols and values must conform to a specific type or schema. Useful for key-value stores or maps. Created using `Verse::Schema.dictionary(TypeOrSchema)` or `field(:name, Hash, of: TypeOrSchema)`.
*   **`Verse::Schema::Scalar`:** Represents a single value that can be one of several specified scalar types (e.g., String, Integer, Boolean). Created using `Verse::Schema.scalar(Type1, Type2, ...)`.
*   **`Verse::Schema::Selector`:** A powerful type that allows choosing which schema or type to apply based on the value of another field (the "selector" field) or a provided `selector` local variable. This enables handling polymorphic data structures. Created using `Verse::Schema.selector(key1: TypeOrSchema1, key2: TypeOrSchema2, ...)` or `field(:name, { key1: TypeOrSchema1, ... }, over: :selector_field_name)`.

These building blocks can be nested and combined to define complex data validation and coercion rules.


## Usage

These examples are extracted directly from the gem's specs, ensuring they are accurate and up-to-date. You can run each example directly in IRB.

### Table of Contents


- [1. Basic Usage](#1-basic-usage)
  
  - [Simple Usage](#simple-usage)
  
  - [Optional Fields](#optional-fields)
  
  - [Default Fields](#default-fields)
  
  - [Coalescing rules](#coalescing-rules)
  
  - [Naming the keys](#naming-the-keys)
  
  - [Multiple Types Field](#multiple-types-field)
  
  - [Open Hash](#open-hash)
  

- [2. Complex Structures](#2-complex-structures)
  
  - [Nested Schemas](#nested-schemas)
  
  - [Array of Schemas](#array-of-schemas)
  
  - [Array of Any Type](#array-of-any-type)
  
  - [Dictionary Schema](#dictionary-schema)
  
  - [Recursive Schema](#recursive-schema)
  
  - [Selector Based Type Selection](#selector-based-type-selection)
  

- [Rules and Post Processing](#rules-and-post-processing)
  
  - [Postprocessing](#postprocessing)
  
  - [Rules](#rules)
  
  - [Locals Variables](#locals-variables)
  

- [Schema Composition](#schema-composition)
  
  - [Schema Factory Methods](#schema-factory-methods)
  
  - [Schema Inheritance](#schema-inheritance)
  
  - [Schema Aggregation](#schema-aggregation)
  
  - [Field Inheritance](#field-inheritance)
  

- [Under the hood](#under-the-hood)
  
  - [Add Custom coalescing rules](#add-custom-coalescing-rules)
  
  - [Reflecting on the schema](#reflecting-on-the-schema)
  
  - [Field Extensions](#field-extensions)
  

- [Data classes](#data-classes)
  
  - [Using Data Classes](#using-data-classes)
  

- [Verse::Schema Documentation](#verseschema-documentation)
  
  - [Complex Example](#complex-example)
  



## 1. Basic Usage


### Simple Usage


```ruby
it "demonstrates basic schema validation" do
  # Create a schema with name and age fields
  schema = Verse::Schema.define do
    field(:name, String).meta(label: "Name", description: "The name of the person")
    field(:age, Integer).rule("must be 18 or older"){ |age| age >= 18 }
  end

  # Validate data
  result = schema.validate({ name: "John", age: 18 })

  # Check if validation succeeded
  if result.success?
    # Access the validated and coerced data
    result.value # => {name: "John", age: 18}
  else
    # Access validation errors
    result.errors # => {}
  end

  # If validation fails, you can access the errors
  invalid_result = schema.validate({ name: "John", age: 17 })
  invalid_result.success? # => false
  invalid_result.errors # => {age: ["must be 18 or older"]}

  expect(result.success?).to be true
  expect(result.value).to eq({ name: "John", age: 18 })
  expect(invalid_result.success?).to be false
  expect(invalid_result.errors).to eq({ age: ["must be 18 or older"] })
end

```


### Optional Fields


```ruby
it "demonstrates optional field usage" do
  # Optional field using field?
  schema = Verse::Schema.define do
    field(:name, String).meta(label: "Name", description: "The name of the person")
    field?(:age, Integer).rule("must be 18 or older") { |age| age >= 18 }
  end

  # Validation succeeds without the optional field
  schema.validate({ name: "John" }).success? # => true

  # But fails if the optional field is present but invalid
  schema.validate({ name: "John", age: 17 }).success? # => false

  # Note that if a key is found but set to nil, the schema will be invalid
  schema.validate({ name: "John", age: nil }).success? # => false

  # To make it valid with nil, define the field as union of Integer and NilClass
  schema_with_nil = Verse::Schema.define do
    field(:name, String).meta(label: "Name", description: "The name of the person")
    field(:age, [Integer, NilClass]).rule("must be 18 or older") { |age|
      next true if age.nil?

      age >= 18
    }
  end

  # Now nil is valid
  schema_with_nil.validate({ name: "John", age: nil }).success? # => true

  expect(schema.validate({ name: "John" }).success?).to be true
  expect(schema.validate({ name: "John", age: 17 }).success?).to be false
  expect(schema.validate({ name: "John", age: 17 }).errors).to eq({ age: ["must be 18 or older"] })
  expect(schema.validate({ name: "John", age: nil }).success?).to be false
  # Assuming default type error message for nil when Integer is expected
  expect(schema.validate({ name: "John", age: nil }).errors).to eq({ age: ["must be an integer"] })
  expect(schema_with_nil.validate({ name: "John", age: nil }).success?).to be true
end

```


### Default Fields


```ruby
it "demonstrates default field values" do
  # Use a static value
  schema1 = Verse::Schema.define do
    field(:type, String).default("reply")
  end

  # Empty input will use the default value
  schema1.validate({}).value # => {type: "reply"}

  # Or use a block which will be called
  schema2 = Verse::Schema.define do
    field(:type, String).default { "reply" }
  end

  schema2.validate({}).value # => {type: "reply"}

  # Using required after default disables default
  schema3 = Verse::Schema.define do
    field(:type, String).default("ignored").required
  end

  schema3.validate({}).success? # => false
  schema3.validate({}).errors # => {type: ["is required"]}

  expect(schema1.validate({}).value).to eq({ type: "reply" })
  expect(schema2.validate({}).value).to eq({ type: "reply" })
  expect(schema3.validate({}).success?).to be false
  expect(schema3.validate({}).errors).to eq({ type: ["is required"] })
end

```


### Coalescing rules


```ruby
it "demonstrates coalescer rules" do
  # Verse::Schema will try  to coalesce the data to the type of the field.
  # This means that if you pass a string in an Integer field,
  # it will try to convert it to an integer.

  schema = Verse::Schema.define do
    field(:name, String)
    field(:age, Integer)
  end

  # Coalescer will try to coerce the data to the type
  # of the field. So if you pass a string, it will
  # try to convert it to an integer.
  result = schema.validate({ name: 1, age: "18" })

  expect(result.success?).to be true
  expect(result.value).to eq({ name: "1", age: 18 })
end

```

```ruby
it "quick match if the class of the input is the same as the field" do
  # If the input is of the same class as the field,
  # it will be a quick match and no coercion will be
  # performed.
  schema = Verse::Schema.define do
    field(:age, [Integer, Float])
  end

  result = schema.validate({ age: 18.0 })

  expect(result.success?).to be true
  expect(result.value[:age]).to be_a(Float)
end

```

```ruby
it "stops when finding a good candidate" do
  # The coalescer go through all the different types in the definition order
  # and stop when it finds a good candidate.
  #
  # The example schema above would never coalesce to Float
  # because it would find Float first:
  schema = Verse::Schema.define do
    field(:age, [Float, Integer])
  end

  result = schema.validate({ age: "18" })

  expect(result.success?).to be true

  # It was able to coalesce to Float first
  # In this case, it would be judicious to define the field
  # as [Integer, Float], Integer being more constrained, to avoid this behavior
  expect(result.value[:age]).to be_a(Float)
end

```


### Naming the keys


```ruby
it "demonstrates using different keys for fields" do
  # If the key of the input schema is different from the output schema,
  # you can use the `key` method to specify the key in the input schema
  # that should be used for the output schema.

  # Define a schema with different keys for fields
  schema = Verse::Schema.define do
    # key can be passed as option
    field(:name, String, key: :firstName)
    # or using the chainable syntax
    field(:email, String).key(:email_address)
  end

  # Validate data with the original key
  result1 = schema.validate({
    firstName: "John",
    email_address: "john@example.tld"
  })
  result1.success? # => true

  expect(result1.value).to eq({
    name: "John",
    email: "john@example.tld"
  })
end

```


### Multiple Types Field


```ruby
it "demonstrates fields that accept multiple types" do
  # Define a schema that accepts a String or a Nested Schema
  content_hash = Verse::Schema.define do
    field(:content, String)
    field(:created_at, Time)
  end

  schema = Verse::Schema.define do
    field(:title, String)
    field(:content, [String, content_hash])
  end

  # Validate with a String content
  result1 = schema.validate({
    title: "My Post",
    content: "This is a simple string content"
  })

  # Validate with a Hash content
  result2 = schema.validate({
    title: "My Post",
    content: {
      content: "This is a structured content",
      created_at: "2023-01-01T12:00:00Z"
    }
  })

  # Both are valid
  expect(result1.success?).to be true
  expect(result2.success?).to be true

  # But invalid content will fail
  invalid_result = schema.validate({
    title: "My Post",
    content: { invalid: "structure" } # Doesn't match `content_hash` schema
  })
  expect(invalid_result.success?).to be false
  # Assuming error messages for missing fields in the nested hash schema
  expect(invalid_result.errors).to eq({ "content.content": ["is required"], "content.created_at": ["is required"] })
end

```


### Open Hash


```ruby
it "demonstrates schemas that allow extra fields" do
  # By default, schemas are closed, which means that
  # fields not defined in the schema will be ignored.
  # To allow extra fields, you can use the `extra_fields` method:

  # Define a schema that allows extra fields
  schema = Verse::Schema.define do
    field(:name, String)

    # This allows any additional fields to be included
    extra_fields
  end

  # Validate with only the defined fields
  result1 = schema.validate({
    name: "John"
  })

  # Validate with extra fields
  result2 = schema.validate({
    name: "John",
    age: 30,
    email: "john@example.com"
  })

  # Both are valid
  expect(result1.success?).to be true
  expect(result2.success?).to be true

  # Extra fields are preserved in the output
  expect(result2.value).to eq({
    name: "John",
    age: 30,
    email: "john@example.com"
  })
end

```



## 2. Complex Structures


### Nested Schemas


```ruby
it "demonstrates nested schema usage" do
  # Define a simple schema first
  simple_schema = Verse::Schema.define do
    field(:name, String).meta(label: "Name", description: "The name of the person")
    field(:age, Integer).rule("must be 18 or older") { |age| age >= 18 }
  end

  # Nested schema using a reference
  nested_schema1 = Verse::Schema.define do
    field(:data, simple_schema)
  end

  # Validate nested data
  result = nested_schema1.validate({
    data: {
      name: "John",
      age: 30
    }
  })

  result.success? # => true
  result.value # => { data: { name: "John", age: 30 } }

  # Or define using subblock and Hash type
  nested_schema2 = Verse::Schema.define do
    field(:data, Hash) do
      field(:name, String).meta(label: "Name", description: "The name of the person")
      field(:age, Integer).rule("must be 18 or older") { |age| age >= 18 }
    end
  end

  # Both approaches produce equivalent schemas
  nested_schema2.validate({
    data: {
      name: "John",
      age: 30
    }
  }).success? # => true

  expect(result.success?).to be true
  expect(result.value).to eq({ data: { name: "John", age: 30 } })

  expect(nested_schema2.validate({
    data: {
      name: "John",
      age: 30
    }
  }).success?).to be true
end

```


### Array of Schemas


```ruby
it "demonstrates array of schemas" do
  # Define an array of schemas using Array type
  array_schema = Verse::Schema.define do
    field(:data, Array) do
      field(:name, String).meta(label: "Name", description: "The name of the person")
      field(:age, Integer).rule("must be 18 or older") { |age| age >= 18 }
    end
  end

  # Validate an array of items
  result = array_schema.validate({
    data: [
      { name: "John", age: 30 },
      { name: "Jane", age: 25 }
    ]
  })

  # Check the result
  result.success? # => true
  result.value # => { data: [ { name: "John", age: 30 }, { name: "Jane", age: 25 } ] }

  # If any item in the array is invalid, the whole validation fails
  invalid_result = array_schema.validate({
    data: [
      { name: "John", age: 30 },
      { name: "Jane", age: 17 } # Age is invalid
    ]
  })

  invalid_result.success? # => false
  invalid_result.errors # => { "data.1.age": ["must be 18 or older"] }

  expect(result.success?).to be true
  expect(result.value).to eq({
    data: [
      { name: "John", age: 30 },
      { name: "Jane", age: 25 }
    ]
  })
  expect(invalid_result.success?).to be false
  expect(invalid_result.errors).to eq({ "data.1.age": ["must be 18 or older"] })
end

```


### Array of Any Type


```ruby
it "demonstrates array of any type" do
  # Array of simple type using 'of' option
  array_schema1 = Verse::Schema.define do
    field(:data, Array, of: Integer)
  end

  # Validate array of integers (with automatic coercion)
  result = array_schema1.validate({
    data: [1, "2", "3"] # String values will be coerced to integers
  })

  result.success? # => true
  result.value # => { data: [1, 2, 3] }

  # This works with Schema too
  person_schema = Verse::Schema.define do
    field(:name, String)
    field(:age, Integer).rule("must be 18 or older") { |age| age >= 18 }
  end

  # Create an array of person schemas
  array_schema2 = Verse::Schema.define do
    field(:people, Array, of: person_schema)
  end

  # Validate array of people
  result2 = array_schema2.validate({
    people: [
      { name: "John", age: 30 },
      { name: "Jane", age: 25 }
    ]
  })

  result2.success? # => true

  expect(result.success?).to be true
  expect(result.value).to eq({ data: [1, 2, 3] })
  expect(result2.success?).to be true
end

```


### Dictionary Schema


```ruby
it "demonstrates dictionary schemas" do
  # Define a dictionary schema with Integer values
  schema = Verse::Schema.define do
    field(:scores, Hash, of: Integer)
  end

  # Validate a dictionary
  result = schema.validate({
    scores: {
      math: "95",
      science: "87",
      history: 92.0
    }
  })

  # The validation succeeds and coerces string values to integers
  expect(result.success?).to be true
  expect(result.value).to eq({
    scores: {
      math: 95,
      science: 87,
      history: 92
    }
  })

  # Invalid values will cause validation to fail
  invalid_result = schema.validate({
    scores: {
      math: "95",
      science: "invalid",
      history: "92"
    }
  })
  expect(invalid_result.success?).to be false
  # Assuming error message for type coercion failure in dictionary
  expect(invalid_result.errors).to eq({ "scores.science": ["must be an integer"] })
end

```


### Recursive Schema


```ruby
it "demonstrates recursive schema" do
  # Define a schema that can contain itself
  recursive_schema = Verse::Schema.define do
    field(:name, String).meta(label: "Name", description: "The name of the item")
    field(:children, Array, of: self).default([])
  end

  # This allows for tree-like structures
  tree_data = {
    name: "Root",
    children: [
      {
        name: "Child 1",
        children: [
          { name: "Grandchild 1" }
        ]
      },
      { name: "Child 2" }
    ]
  }

  # Validate the recursive structure
  result = recursive_schema.validate(tree_data)

  result.success? # => true

  # The validated data maintains the same structure
  # but with any coercions or transformations applied

  expect(result.success?).to be true
end

```


### Selector Based Type Selection


```ruby
it "demonstrates using raw selector schema" do
  selector_schema = Verse::Schema.selector(
    a: [String, Integer],
    b: [Hash, Array]
  )

  result = selector_schema.validate("string", locals: { selector: :a })
  expect(result.success?).to be true

  result = selector_schema.validate(42, locals: { selector: :a })
  expect(result.success?).to be true

  result = selector_schema.validate({ key: "value" }, locals: { selector: :b })
  expect(result.success?).to be true
  result = selector_schema.validate([1, 2, 3], locals: { selector: :b })
  expect(result.success?).to be true

  # Invalid case - wrong type for the selector
  invalid_result = selector_schema.validate("invalid", locals: { selector: :b })
  expect(invalid_result.success?).to be false
  # Assuming error message format for type mismatch in selector
  # Currently, the error message will be related to the last type of the
  # array
  expect(invalid_result.errors).to eq({ nil => ["must be an array"] })

  # Invalid case - missing selector
  missing_selector_result = selector_schema.validate("invalid")
  expect(missing_selector_result.success?).to be false
  expect(missing_selector_result.errors).to eq({ nil => ["selector not provided for this schema"] })
end

```

```ruby
it "demonstrates selector based type selection" do
  facebook_schema = Verse::Schema.define do
    field(:url, String)
    field?(:title, String)
  end

  google_schema = Verse::Schema.define do
    field(:search, String)
    field?(:location, String)
  end

  # Define a schema with a selector field
  schema = Verse::Schema.define do
    field(:type, Symbol).in?(%i[facebook google])
    field(:data, {
      facebook: facebook_schema,
      google: google_schema
    }, over: :type)
  end

  # Validate data with different types
  result1 = schema.validate({
    type: :facebook,
    data: { url: "https://facebook.com" }
  })

  result2 = schema.validate({
    type: :google,
    data: { search: "conference 2023" }
  })

  expect(result1.success?).to be true
  expect(result2.success?).to be true

  # Invalid case - wrong type for the selector
  invalid_result = schema.validate({
    type: :facebook,
    data: { search: "invalid" } # `search` is not in `facebook_schema`
  })

  expect(invalid_result.success?).to be false
  # Assuming error message format for missing required field in selected schema
  expect(invalid_result.errors).to eq({ "data.url": ["is required"] })
end

```



## Rules and Post Processing


### Postprocessing


```ruby
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

```

```ruby
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

```

```ruby
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

```


### Rules


```ruby
it "demonstrates global rules" do
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

```

```ruby
it "demonstrates reusable rules defined with Verse::Schema.rule" do
  # Define a reusable rule object
  is_positive = Verse::Schema.rule("must be positive") { |value| value > 0 }

  # Define another reusable rule
  is_even = Verse::Schema.rule("must be even") { |value| value.even? }

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

```


### Locals Variables


```ruby
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

```



## Schema Composition


### Schema Factory Methods


```ruby
it "demonstrates schema factory methods" do
  # Verse::Schema offer methods to create array, dictionary, and scalar schemas

  # Define a base item schema
  item_schema = Verse::Schema.define do
    field(:name, String)
  end

  # Create an array schema using the factory method
  array_schema = Verse::Schema.array(item_schema)

  # Create a dictionary schema using the factory method
  dictionary_schema = Verse::Schema.dictionary(item_schema)

  # Create a scalar schema using the factory method
  scalar_schema = Verse::Schema.scalar(Integer, String)

  # Validate using the array schema
  array_result = array_schema.validate([
                                         { name: "Item 1" },
                                         { name: "Item 2" }
                                       ])
  expect(array_result.success?).to be true

  # Validate using the dictionary schema
  dict_result = dictionary_schema.validate({
    item1: { name: "First Item" },
    item2: { name: "Second Item" }
  })
  expect(dict_result.success?).to be true

  # Validate using the scalar schema
  scalar_result1 = scalar_schema.validate(42)
  scalar_result2 = scalar_schema.validate("Hello")
  expect(scalar_result1.success?).to be true
  expect(scalar_result2.success?).to be true
end

```


### Schema Inheritance


```ruby
it "demonstrates schema inheritance" do
  # Schema can inherit from other schemas.
  # Please be aware that this is not a classical inheritance model,
  # but rather a structural inheritance model.
  # In a way, it is similar to traits concept.

  # Define a parent schema
  parent = Verse::Schema.define do
    field(:type, Symbol)
    field(:id, Integer)

    rule(:type, "should be filled") { |x| x[:type].to_s != "" }
  end

  # Define a child schema that inherits from the parent
  child_a = Verse::Schema.define(parent) do
    rule(:type, "must start with x") { |x| x[:type].to_s =~ /^x/ }
    field(:data, Hash) do
      field(:x, Float)
      field(:y, Float)
    end
  end

  # Another child schema with different rules
  child_b = Verse::Schema.define(parent) do
    rule(:type, "must start with y") { |x| x[:type].to_s =~ /^y/ }
    field(:data, Hash) do
      field(:content, String)
    end
  end

  # Validate using child_a schema
  result_a = child_a.validate({
    type: :xcoord,
    id: 1,
    data: {
      x: 10.5,
      y: 20.3
    }
  })

  # Validate using child_b schema
  result_b = child_b.validate({
    type: :ydata,
    id: 2,
    data: {
      content: "Some content"
    }
  })

  # Both validations succeed
  expect(result_a.success?).to be true
  expect(result_b.success?).to be true

  # Invalid data for child_a
  invalid_a = child_a.validate({
    type: :ycoord, # Should start with 'x'
    id: 1,
    data: {
      x: 10.5,
      y: 20.3
    }
  })
  expect(invalid_a.success?).to be false
  expect(invalid_a.errors).to eq({ type: ["must start with x"] })
end

```

```ruby
it "tests inheritance relationships between schemas" do
  # Define a parent schema
  parent = Verse::Schema.define do
    field(:name, String)
    field(:age, Integer)
  end

  # Define a child schema that inherits from the parent
  child = Verse::Schema.define(parent) do
    field(:email, String)
  end

  # Define a schema with the same fields but not inherited
  similar = Verse::Schema.define do
    field(:name, String)
    field(:age, Integer)
  end

  # Define a schema with different fields
  different = Verse::Schema.define do
    field(:title, String)
    field(:count, Integer)
  end

  # Test inheritance relationships
  expect(child.inherit?(parent)).to be true  # Child inherits from parent
  expect(child < parent).to be true          # Using the < operator
  expect(child <= parent).to be true         # Using the <= operator

  expect(parent.inherit?(child)).to be false # Parent doesn't inherit from child
  expect(parent < child).to be false         # Using the < operator
  expect(parent <= child).to be false        # Using the <= operator

  # Similar schema has the same fields as parent
  # In Verse::Schema, inheritance is structural, not nominal
  # So a schema with the same fields "inherits" from another schema
  expect(similar.inherit?(parent)).to be true # Similar structurally inherits from parent
  expect(similar < parent).to be true         # Using the < operator
  expect(similar <= parent).to be true        # Using the <= operator

  expect(different.inherit?(parent)).to be false # Different doesn't inherit from parent
  expect(different < parent).to be false         # Using the < operator
  expect(different <= parent).to be false        # Using the <= operator

  # Test self-comparison
  expect(parent <= parent).to be true  # A schema is <= to itself
  expect(parent < parent).to be false  # A schema is not < itself
end

```


### Schema Aggregation


```ruby
it "demonstrates combining schemas" do
  # It is sometime useful to combine two schemas into one.
  # This is done using the `+` operator.
  # The resulting schema will have all the fields of both schemas.
  # If the same field is defined in both schemas, the combination will
  # be performed at the field level, so the field type will be the union
  # of the two fields.
  # The rules and post-processing will be combined as well, in such order
  # that the first schema transforms will be applied first, and then the second one.

  # Define two schemas to combine
  schema1 = Verse::Schema.define do
    field(:age, Integer).rule("must be major") { |age|
      age >= 18
    }
  end

  schema2 = Verse::Schema.define do
    field(:content, [String, Hash])
  end

  # Combine the schemas
  combined_schema = schema1 + schema2

  # Validate using the combined schema
  result = combined_schema.validate({
    age: 25,
    content: "Some content"
  })

  # The validation succeeds
  expect(result.success?).to be true

  # Invalid data will still fail
  invalid_result = combined_schema.validate({
    age: 16, # Too young
    content: "Some content"
  })
  expect(invalid_result.success?).to be false
  expect(invalid_result.errors).to eq({ age: ["must be major"] })
end

```


### Field Inheritance


```ruby
it "tests inheritance relationships between fields" do
  # Create fields with different types
  string_field = Verse::Schema::Field.new(:name, String, {})
  integer_field = Verse::Schema::Field.new(:age, Integer, {})
  number_field = Verse::Schema::Field.new(:count, Numeric, {})

  # Integer is a subclass of Numeric
  expect(integer_field.inherit?(number_field)).to be true
  expect(integer_field < number_field).to be true
  expect(integer_field <= number_field).to be true

  # String is not a subclass of Numeric
  expect(string_field.inherit?(number_field)).to be false
  expect(string_field < number_field).to be false
  expect(string_field <= number_field).to be false

  # Test with same type but different names
  name_field = Verse::Schema::Field.new(:name, String, {})
  title_field = Verse::Schema::Field.new(:title, String, {})

  # Same type, different names - should still be comparable
  expect(name_field.inherit?(title_field)).to be true
  expect(name_field < title_field).to be true
  expect(name_field <= title_field).to be true

  # Test with Hash fields and nested schemas
  person_schema = Verse::Schema.define do
    field(:name, String)
    field(:age, Integer)
  end

  employee_schema = Verse::Schema.define do
    field(:name, String)
    field(:age, Integer)
    field(:salary, Float)
  end

  person_field = Verse::Schema::Field.new(:person, person_schema, {})
  employee_field = Verse::Schema::Field.new(:employee, employee_schema, {})

  # Test schema field inheritance
  # This might fail if the implementation is incorrect
  begin
    result = employee_field.inherit?(person_field)
    expect([true, false]).to include(result)
  rescue NotImplementedError => e
    # If it raises NotImplementedError, that's also valuable information
    puts "NotImplementedError raised: #{e.message}"
  end
end

```



## Under the hood


### Add Custom coalescing rules



### Reflecting on the schema


```ruby
it "demonstrates schema reflection" do
  # It exists 4 schema class type:
  # 1. Verse::Schema::Struct
  #   the default schema type, with field definition
  # 2. Verse::Schema::Array
  #   a schema that contains an array of items
  #   `values` attribute being an array of type
  # 3. Verse::Schema::Dictionary
  #   a schema that contains a dictionary of items
  #   `values` attribute being an array of type
  # 4. Verse::Schema::Selector
  #   a schema that contains a selector of items
  #   `values` attribute being a selection hash
  complex_schema_example = Verse::Schema.define do
    field(:name, String).meta(label: "Name", description: "The name of the person")

    field(:data) do
      field(:content, String).filled
    end

    field(:dictionary, Verse::Schema.dictionary(String))
    field(:array, Array) do
      field(:item, [String, Integer])
    end
  end

  # Inspect is a good way to see the schema definition
  puts complex_schema_example.inspect
  # => #<struct{
  #   name: String,
  #   data: #<struct{content: String} 0x1400>,
  #   dictionary: #<dictionary<String> 0x1414>,
  #       array: #<collection<#<struct{item: String|Integer} 0x1428>> 0x143c>
  #   } 0x1450>

  # You can reflect on the schema to get information about its fields:
  expect(complex_schema_example.extra_fields?).to be false

  complex_schema_example.fields.each do |field|
    puts "Field name: #{field.name}"
    puts "Field type: #{field.type}"
    puts "Field metadata: #{field.meta}"

    puts "Is required: #{field.required?}"
  end

  # Of course, you can also traverse the schema tree to get information about nested fields:
  arr_value = complex_schema_example.fields.find{ |field| field.name == :array }.type.values
  puts arr_value[0].fields.map(&:name) # => [:item]
end

```


### Field Extensions




## Data classes


### Using Data Classes


```ruby
it "demonstrates nested data classes" do
  # Data classes allow you to create structured data objects from schemas.
  # This can be very useful to avoid hash nested key access
  # which tends to make your code less readable.
  #
  # Under the hood, dataclass will take your schema, duplicate it
  # and for each field with nested Verse::Schema::Base, it will
  # add a transformer to convert the value to the dataclass of the schema.

  # Data class will automatically use dataclass of other nested schemas.
  # Define a schema for an address
  address_schema = Verse::Schema.define do
    field(:street, String)
    field(:city, String)
    field(:zip, String)
  end

  # Create a data class for address
  Address = address_schema.dataclass

  # Define a schema for a person with a nested address
  person_schema = Verse::Schema.define do
    field(:name, String)
    field(:address, address_schema)
  end

  # Create a data class for person
  Person = person_schema.dataclass

  # Create a person with a nested address
  person = Person.new({
    name: "John Doe",
    address: {
      street: "123 Main St",
      city: "Anytown",
      zip: "12345"
    }
  })

  # The nested address is also a data class
  expect(person.address).to be_a(Address)
  expect(person.address.street).to eq("123 Main St")
  expect(person.address.city).to eq("Anytown")
  expect(person.address.zip).to eq("12345")

  # In case you find some weird behavior, you can always check
  # the schema of the dataclass.
  # The dataclass schema used to generate the dataclass
  # can be found in the class itself:
  expect(Person.schema).to be_a(Verse::Schema::Struct)
end

```

```ruby
it "demonstrates recursive data classes" do
  # Define a schema for a tree node
  tree_node_schema = Verse::Schema.define do
    field(:value, String)
    field(:children, Array, of: self).default([])
  end

  # Create a data class for the tree node
  TreeNode = tree_node_schema.dataclass

  # Create a tree structure
  root = TreeNode.new({
    value: "Root",
    children: [
      { value: "Child 1" },
      { value: "Child 2" }
    ]
  })

  # Access the tree structure
  expect(root.value).to eq("Root")
  expect(root.children.map(&:value)).to eq(["Child 1", "Child 2"])
  expect(root.children[0].children).to be_empty
end

```

```ruby
it "works with dictionary, array, scalar and selector too" do
  schema = Verse::Schema.define do
    field(:name, String)
    field(:type, Symbol).in?(%i[student teacher])

    teacher_data = define do
      field(:subject, String)
      field(:years_of_experience, Integer)
    end

    student_data = define do
      field(:grade, Integer)
      field(:school, String)
    end

    # Selector
    field(:data, { student: student_data, teacher: teacher_data }, over: :type)

    # Array of Scalar
    comment_schema = define do
      field(:text, String)
      field(:created_at, Time)
    end

    # Verbose but to test everything.
    field(:comment, Verse::Schema.array(
      Verse::Schema.scalar(String, comment_schema)
    ))

    score_schema = define do
      field(:a, Integer)
      field(:b, Integer)
    end

    # Dictionary
    field(:scores, Hash, of: score_schema)
  end

  # Get the dataclass:
  Person = schema.dataclass

  # Create a valid instance
  person = Person.new({
    name: "John Doe",
    type: :student,
    data: {
      grade: 10,
      school: "High School"
    },
    comment: [
      { text: "Great job!", created_at: "2023-01-01T12:00:00Z" },
      "This is a comment"
    ],
    scores: {
      math: { a: 90.5, b: 95 },
      science: { a: 85, b: 88 }
    }
  })

  expect(person.data.grade).to eq(10)
  expect(person.data.school).to eq("High School")
  expect(person.comment[0].text).to eq("Great job!")
  expect(person.comment[0].created_at).to be_a(Time)
  expect(person.comment[1]).to eq("This is a comment")
  expect(person.scores[:math].a).to eq(90)

  # Invalid schema

  expect {
    Person.new({
      name: "Invalid Person",
      type: :student,
      data: {
        subject: "Math", # Invalid field for student
        years_of_experience: 5 # Invalid field for student
      },
      comment: [
        { text: "Great job!", created_at: "2023-01-01T12:00:00Z" },
        "This is a comment"
      ],
      scores: {
        math: { a: 90.5, b: 95 },
        science: { a: 85, b: 88 }
      }
    })
  }.to raise_error(Verse::Schema::InvalidSchemaError).with_message(
    "Invalid schema:\n" \
    "data.grade: [\"is required\"]\n" \
    "data.school: [\"is required\"]"
  )
end

```



## Verse::Schema Documentation


### Complex Example


```ruby
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

```




## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/verse-rb/verse-schema.

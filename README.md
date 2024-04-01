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

## Usage

### Simple usage

```ruby
  must_be_major = Verse::Schema.rule("must be 18 or older") do |value|
    value >= 18
  end

  # a simple schema with a rule
  schema = Verse::Schema.define do
    field(:name, String).label("Name").description("The name of the person").filled
    field(:age, Integer).rule(must_be_major)
  end

  # validate data
  result = schema.validate({name: "John", age: 18})

  if result.success?
    puts "Valid data: #{result.value}"
  else
    puts "Invalid data"
    puts result.errors
  end
```

### Optional fields

use `field?` or `field(...).optional` to make it optional.
If the key is not found, it will be ignored.

```ruby
  # optional field
  Verse::Schema.define do
    field(:name, String).label("Name").description("The name of the person")
    field?(:age, Integer).rule("must be 18 or older") { |age| age >= 18 }
  end
```

Note that if a key is found but set at nil, the schema will be invalid:

```ruby
  # optional field
  Verse::Schema.define do
    field(:name, String).label("Name").description("The name of the person")
    field?(:age, Integer).rule("must be 18 or older") { |age| age >= 18 }
  end

  schema.validate({name: "John", age: nil}).success? # => false
```

To make it valid, you can define the field as union of `Integer` and `NilClass`:

```ruby
  # optional field
  Verse::Schema.define do
    field(:name, String).label("Name").description("The name of the person")
    field(:age, [Integer, NilClass]).rule("must be 18 or older") { |age| next true if age.nil?; age>=18 }
  end

  schema.validate({name: "John", age: nil}).success? # => true
```

Note also the change in the rule, as the age can be `nil`, we need to handle it.

### Default Field

Use `default` to setup default field:

```ruby
  # Use a static value
  field(:type, String).default("reply")

  # or use a block which will be called:
  field(:type, String).default{ "reply" }
```

Using `required` after `default` disable default:

```ruby
  field(:type, String).default("ignored").required
```

Default are called in front of the post-processing chain.

This won't work:

```ruby
  field(:type, String).default{ MyClass.new("default") }.transform { |x| MyClass.new(x) }
```

Because the type testing is made AFTER the default value is set.

This however can become handy to force a transformer like this the example below:

```ruby
  field(:type, [String, NilClass]).default(nil).transform{ |x|
    MyClass.new(x || "default")
  }
```

### Nested schemas:

Use of `Verse::Schema` as a field type allows to define nested schemas:

```ruby
  simple_schema = Verse::Schema.define do
    field(:name, String).label("Name").description("The name of the person").filled
    field(:age, Integer).rule(MUST_BE_MAJOR)
  end
  # nested schema
  nested_schema = Verse::Schema.define do
    # Hash of simple schema
    field(:data, simple_schema)
  end
```

You can also define using subblock and `Hash` type:

```ruby
  # nested schema
  nested_schema = Verse::Schema.define do
    # Hash of simple schema
    field(:data, Hash) do
      field(:name, String).label("Name").description("The name of the person").filled
      field(:age, Integer).rule(MUST_BE_MAJOR)
    end
  end
```

### Array of schemas

You can define an array of schemas using `Array` type:

```ruby
  # array of simple schema
  array_schema = Verse::Schema.define do
    field(:data, Array) do
      field(:name, String).label("Name").description("The name of the person").filled
      field(:age, Integer).rule(MUST_BE_MAJOR)
    end
  end
```

### Array of any type

Same as Hash, use `of` option to validate each Array item:

```ruby
  # array of simple schema
  array_schema = Verse::Schema.define do
    field(:data, Array, of: Integer)
  end
```

This work with Schema too:


```ruby
  simple_schema = Verse::Schema.define do
    field(:name, String).label("Name").description("The name of the person").filled
    field(:age, Integer).rule(MUST_BE_MAJOR)
  end

  # array of simple schema
  array_schema = Verse::Schema.define do
    field(:data, Array, of: simple_schema)
  end
```

Or you can pass a block:

```ruby
  # array of simple schema
  array_schema = Verse::Schema.define do
    field(:data, Array) do
      field(:name, String).label("Name").description("The name of the person").filled
      field(:age, Integer).rule(MUST_BE_MAJOR)
    end
  end
```

Please note that due to the coalescence process, the array will be coerced to the type defined in the schema:

```ruby
  # array of simple schema
  array_schema = Verse::Schema.define do
    field(:data, Array, of: [Integer, String])
  end

  array_schema.validate({data: [1, "2", "3"]}).value # => [1, 2, 3]
```

Here everything become Integer as the first type in `of` option is Integer and coercion is applied.

### Rules

Rules can be setup on fields as seen above. You can also define global rules that will be applied to the whole schema:

```ruby
  # multiple fields rule
  multiple_field_rule_schema = Verse::Schema.define do
    field(:name, String)
    field(:age, Integer)

    rule(%i[age name], "age must be 18 and name must NOT be John") do |schema|
      schema[:age] >= 18 && schema[:name] != "John"
    end
  end
```

### Locals variables

Locals variables can be passed during the validation process:

```ruby
  schema = Verse::Schema.define do
    field(:age, Integer).rule("must be greater than %{min_age}") { |age|
      age > locals[:min_age]
    }
  end

  schema.validate({age: 18}, locals: { min_age: 21 }).success? # => false
```

### Custom types

By default, the Coalescer will try to coerce the data to the type defined in the schema for those basic types:
- String
- Integer
- Float
- TrueClass (aka Boolean)
- Nil
- Time (as DateTime)
- Date (as Date only)
- Hash
- Array

Any other object type and the Coalescer will just check that the entry value is matching the type:

```ruby
  field(:name, Object) # Aka. any object
```

You can register your own converter type:

```ruby
  Verse::Schema::Coalescer.register(Email) do |value, opts|
    case value
    when Email
      next value
    when String
      Email.valid?(value) && (next Email.new(value))
    end

    raise Verse::Schema::Coalescer::Error, "invalid email: #{value}"
  end
```

`opts` is a Hash of options you can pass to the `field` method:

```ruby
  # (note: example of option not implemented in the code above.)
  field(:email, Email, downcase: true)
```

### Postprocessing

After coalescence, Verse::Schema is running the post-processors. Those are `rules` and `transform`.

Example:

```ruby
  Event = Struct.new(:type, :data, :created_at)

  event_schema = Verse::Schema.define do
    field(:type, String)
    field(:data, Hash).transform{ |input| input.transform_keys(&:to_sym) }
    field(:created_at, Time)

    # Transform the output of this schema definition.
    transform do |input|
      Event.new(input[:type], input[:data], input[:created_at])
    end
  end

  output = event_schema.validate(
    type: "user.created",
    data: { name: "John" },
    created_at: "2020-01-01T00:00:00Z"
  ).value

  output.class # => Event
```

This is useful to cast output hash into objects, to unwrap complex structures etc...

- Rules are special case of `transform`, as they are not mutating the output, but they are validating it.
- `rule` and `transform` are run in the order of definition. They take in input the output of the previous post-processor.

### Adding features to your fields

You can reopen the `Verse::Schema::Field` object and add helper methods. Here are the standard ones shipped with Verse::Schema

```ruby
module Verse
  module Schema
    class Field
      def filled(message = "must be filled")
        rule(message) do |value, _output|
          if value.respond_to?(:empty?)
            !value.empty?
          elsif !value
            false
          else
            true
          end
        end
      end

      def in?(values, message="must be one of %s")
        rule(message % values.join(", ")) do |value, _output|
          values.include?(value)
        end
      end
    end
  end
end
```

You can add optional informations to your fields too (e.g. for documentation purpose):

```ruby
Verse::Schema::Field.option :meta, default: {}
```

You can reflect on the schema to get the fields:

```ruby
schema = Verse::Schema.define do
  field(:name, String).label("Name").description("The name of the person").filled
  field(:age, Integer).rule(MUST_BE_MAJOR)
end

schema.fields.each do |field|
  puts "#{field.name} - #{field.label}"
  puts "---"
  puts field.description
end
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/verse-rb/verse-schema.

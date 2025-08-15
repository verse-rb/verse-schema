# frozen_string_literal: true

require "bundler"

Bundler.require

require "verse/schema"
require "benchmark"

puts "Starting benchmark..."

# Simple Struct
# ----------------
puts "\n\n--- Simple Struct ---"

SimpleStructSchema = Verse::Schema.define do
  field(:name, String)
  field(:age, Integer)
end

SimpleStructSchemaCompiled = Verse::Schema.define do
  field(:name, String)
  field(:age, Integer)
end
SimpleStructSchemaCompiled.freeze

SimpleDataclass = SimpleStructSchema.dataclass

struct_input = { name: "John", age: 30 }

Benchmark.ips do |x|
  x.report("Schema") { SimpleStructSchema.validate(struct_input) }
  x.report("Compiled Schema") { SimpleStructSchemaCompiled.validate(struct_input) }
  x.report("Dataclass") { SimpleDataclass.new(struct_input) }
  x.compare!
end

# Array
# ----------------
puts "\n\n--- Array ---"
ArraySchema = Verse::Schema.define do
  field(:values, Array, of: [String, Integer])
end
ArraySchemaCompiled = ArraySchema.dup.freeze
ArrayDataclass = ArraySchema.dataclass

array_input = {values: ["John", 30]}

Benchmark.ips do |x|
  x.report("Schema") { ArraySchema.validate(array_input) }
  x.report("Compiled Schema") { ArraySchemaCompiled.validate(array_input) }
  x.report("Dataclass") { ArrayDataclass.new(array_input) }
  x.compare!
end

# Nested Schema
# ----------------
puts "\n\n--- Nested Schema ---"
NestedSchema = Verse::Schema.define do
  field(:person, SimpleStructSchema)
end
NestedSchemaCompiled = NestedSchema.dup.freeze
NestedDataclass = NestedSchema.dataclass
nested_input = { person: { name: "John", age: 30 } }
Benchmark.ips do |x|
  x.report("Schema") { NestedSchema.validate(nested_input) }
  x.report("Compiled Schema") { NestedSchemaCompiled.validate(nested_input) }
  x.report("Dataclass") { NestedDataclass.new(nested_input) }
  x.compare!
end

# Selector
# ----------------
puts "\n\n--- Selector ---"
UserSchema = Verse::Schema.define do
  field(:name, String)
  field(:age, Integer)
end

AdminSchema = Verse::Schema.define(UserSchema) do
  field(:admin_level, Integer)
end

SelectorSchema = Verse::Schema.define do
  field(:type, Symbol)
  field(:data, {
      user: UserSchema,
      admin: AdminSchema
  }, over: :type)
end

SelectorSchemaCompiled = SelectorSchema.dup.freeze
SelectorDataclass = SelectorSchema.dataclass

selector_input = { type: "user", data: { name: "John", age: 30 } }

Benchmark.ips do |x|
  x.report("Schema") { SelectorSchema.validate(selector_input) }
  x.report("Compiled Schema") { SelectorSchemaCompiled.validate(selector_input) }
  x.report("Dataclass") { SelectorDataclass.new(selector_input) }
  x.compare!
end

# Complex real life example
# ----------------
puts "\n\n--- Complex Real Life Example ---"
# Good real life example struggling in term of perfs
ComplexExample = Verse::Schema.define do
  field :from, Time
  field :to, Time

  field? :project_id, [Integer, NilClass]

  field :productive, TrueClass
  field :billable, TrueClass

  field(:details, String).default("")

  rule :from, "from should be less than to" do |object|
    next object[:from] <= object[:to]
  end

  rule :project_id, "Project id must be set if productive set to true" do |object|
    if object[:productive] && object[:project_id].nil?
      next false
    end

    true
  end

  rule :project_id, "Billable must have a project_id" do |object|
    if object[:billable] && object[:project_id].nil?
      next false
    end

    true
  end
end

ComplexExampleCompiled = ComplexExample.dup.freeze
ComplexDataclass = ComplexExample.dataclass
complex_input = {
  "to" => "2024-10-16 12:00:00",
  "from" => "2024-10-16 04:00:00",
  "details" => "Worked on the project",
  "billable" => true,
  "productive" => true,
  "project_id" => 1
}
Benchmark.ips do |x|
  x.report("Schema") { ComplexExample.validate(complex_input) }
  x.report("Compiled Schema") { ComplexExampleCompiled.validate(complex_input) }
  x.report("Dataclass") { ComplexDataclass.new(complex_input) }
  x.compare!
end

# frozen_string_literal: true

require_relative "../../../spec_helper"

RSpec.describe "Data classes", :readme do
  context "Using Data Classes", :readme_section do
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
      # rubocop:disable Lint/ConstantDefinitionInBlock
      Address = address_schema.dataclass

      # Define a schema for a person with a nested address
      person_schema = Verse::Schema.define do
        field(:name, String)
        field(:address, address_schema)
      end

      # Create a data class for person
      Person = person_schema.dataclass
      # rubocop:enable Lint/ConstantDefinitionInBlock

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

    it "demonstrates recursive data classes" do
      # Define a schema for a tree node
      tree_node_schema = Verse::Schema.define do
        field(:value, String)
        field(:children, Array, of: self).default([])
      end

      # Create a data class for the tree node
      # rubocop:disable Lint/ConstantDefinitionInBlock
      TreeNode = tree_node_schema.dataclass
      # rubocop:enable Lint/ConstantDefinitionInBlock

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
      # rubocop:disable Lint/ConstantDefinitionInBlock
      Person = schema.dataclass
      # rubocop:enable Lint/ConstantDefinitionInBlock

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
  end
end
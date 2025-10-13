# frozen_string_literal: true

module Verse
  module Schema
    module Json
      # @param schema [Verse::Schema::Base] The schema to convert to JSON schema
      # @return [Hash] The JSON schema
      def self.from(schema)
        definitions = {}
        output = _from_schema(schema, registry: {}, definitions: definitions)

        if definitions.any?
          output[:"$defs"] = definitions
        end

        output
      end

      private

      def self._from_schema(schema, registry:, definitions:)
        return { :"$ref" => registry[schema.object_id] } if registry.key?(schema.object_id)


        if schema.is_a?(Verse::Schema::Base)
          # Register the schema to handle recursion
          # and give it a name.
          # The name is based on the class name, or the object_id if the class is anonymous.
          name = :"Schema#{schema.object_id}"
          ref = "#/$defs/#{name}"

          registry[schema.object_id] = ref
          definitions[name] = _build_schema(schema, registry: registry, definitions: definitions)

          return { :"$ref" => ref }
        end

        _build_schema(schema, registry: registry, definitions: definitions)
      end

      def self._build_schema(schema, registry:, definitions:)
        case schema
        when Verse::Schema::Struct
          properties = schema.fields.each_with_object({}) do |field, obj|
            obj[field.name] = begin
              output = _from_schema(field.type, registry: registry, definitions: definitions)
              desc = field.opts.dig(:meta, :description)

              output[:description] = desc if desc

              default = field.opts[:default]

              if default && !default.is_a?(Proc)
                output[:default] = default
              end

              output
            end
          end

          required_fields = schema.fields.select(&:required?).map(&:name)

          json = {
            type: "object",
            properties: properties
          }
          json[:required] = required_fields if required_fields.any?
          json[:additionalProperties] = schema.extra_fields?

          json
        when Verse::Schema::Collection
          items = if schema.values.length > 1
                    { anyOf: schema.values.map { |v| _from_schema(v, registry: registry, definitions: definitions) } }
                  else
                    _from_schema(schema.values.first, registry: registry, definitions: definitions)
                  end

          {
            type: "array",
            items: items
          }
        when Verse::Schema::Dictionary
          additional_properties = if schema.values.length > 1
                                    { anyOf: schema.values.map { |v| _from_schema(v, registry: registry, definitions: definitions) } }
                                  else
                                    _from_schema(schema.values.first, registry: registry, definitions: definitions)
                                  end
          {
            type: "object",
            additionalProperties: additional_properties
          }
        when Verse::Schema::Scalar
          {
            anyOf: schema.values.map { |v| _from_schema(v, registry: registry, definitions: definitions) }
          }
        when Verse::Schema::Selector
          {
            :"oneOf" => schema.values.map do |key, sub_schema|
              {
                if: {
                  properties: { schema.discriminator.to_s => { "const" => key.to_s } }
                },
                then: _from_schema(sub_schema, registry: registry, definitions: definitions)
              }
            end
          }
        when String.singleton_class, Symbol.singleton_class
          { type: "string" }
        when Integer.singleton_class
          { type: "integer" }
        when Float.singleton_class, Numeric.singleton_class
          { type: "number" }
        when TrueClass.singleton_class, FalseClass.singleton_class
          { type: "boolean" }
        when Time.singleton_class
          { type: "string", format: "date-time" }
        when NilClass.singleton_class, nil
          { type: "null" }
        else
          raise "Unknown type #{schema.inspect}"
        end
      end
    end
  end
end

# frozen_string_literal: true

module Verse
  module Schema
    module Json
      # rubocop:disable Lint/HashCompareByIdentity
      # @param schema [Verse::Schema::Base] The schema to convert to JSON schema
      # @return [Hash] The JSON schema
      def self.from(schema)
        definitions = {}
        # directly build the root schema, don't use a ref.
        output = _build_schema(schema, registry: {}, definitions: definitions)

        if definitions.any?
          output[:"$defs"] = definitions
        end

        output
      end

      def self._from_schema(schema, registry:, definitions:)
        return { "$ref": registry[schema.object_id] } if registry.key?(schema.object_id)

        if schema.is_a?(Verse::Schema::Struct)
          # Register the schema to handle recursion
          # and give it a name.
          # The name is based on the class name, or the object_id if the class is anonymous.
          name = :"Schema#{schema.object_id}"
          ref = "#/$defs/#{name}"

          registry[schema.object_id] = ref

          # if it's the root schema, don't create a definition, just build it.
          built_schema = _build_schema(schema, registry:, definitions:)

          definitions[name] = built_schema

          return { "$ref": ref }
        end

        _build_schema(schema, registry:, definitions:)
      end

      def self._build_schema(schema, registry:, definitions:)
        case schema
        when Verse::Schema::Struct
          properties = schema.fields.each_with_object({}) do |field_obj, obj|
            next if field_obj.type.is_a?(Verse::Schema::Selector)

            obj[field_obj.name] = begin
              output = _from_schema(field_obj.type, registry:, definitions:)
              desc = field_obj.opts.dig(:meta, :description)

              output[:description] = desc if desc

              default = field_obj.opts[:default]

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

          # Handle selectors
          schema.fields.each do |field_obj|
            next unless field_obj.type.is_a?(Verse::Schema::Selector)

            discriminator = field_obj.opts[:over]
            json[:properties][field_obj.name] = { type: "object" }

            selector_keys = field_obj.type.values.keys
            if !selector_keys.include?(:__else__)
              json[:properties][discriminator][:enum] = selector_keys.map(&:to_s)
            end

            json[:allOf] = field_obj.type.values.map do |key, sub_schema|
              next if key == :__else__

              {
                if: {
                  properties: { discriminator.to_sym => { const: key.to_s } }
                },
                then: {
                  properties: {
                    field_obj.name => _from_schema(sub_schema, registry:, definitions:)
                  }
                }
              }
            end.compact
          end

          json
        when Verse::Schema::Collection
          items = if schema.values.length > 1
                    { anyOf: schema.values.map { |v| _from_schema(v, registry:, definitions:) } }
                  else
                    _from_schema(schema.values.first, registry:, definitions:)
                  end

          {
            type: "array",
            items: items
          }
        when Verse::Schema::Dictionary
          additional_properties = if schema.values.length > 1
                                    { anyOf: schema.values.map { |v| _from_schema(v, registry:, definitions:) } }
                                  else
                                    _from_schema(schema.values.first, registry:, definitions:)
                                  end
          {
            type: "object",
            additionalProperties: additional_properties
          }
        when Verse::Schema::Scalar
          {
            anyOf: schema.values.map { |v| _from_schema(v, registry:, definitions:) }
          }
        when Verse::Schema::Selector
          # This should not be reached directly for a valid schema with `over`
          raise "Selector schema must be used within a Struct with `over` option."
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
        when Array.singleton_class
          { type: "array" }
        when Array
          case schema.length
          when 0
            { type: "null" }
          when 1
            _from_schema(schema.first, registry:, definitions:)
          else
            { anyOf: schema.map { |v| _from_schema(v, registry:, definitions:) } }
          end
        when Object
          {} # no type restriction for generic objects
        else
          raise "Unknown type #{schema.inspect}"
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/CyclomaticComplexity, Lint/HashCompareByIdentity
    end
  end
end

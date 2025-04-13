module Verse
  module Schema
    # Transform a schema which should output a hash into
    # a schema which will output recursively value objects.
    module ValueObjectBuilder
      module_function

      def build(schema)
        case schema
        when Array
          schema.map{ |s| build(s) }
        when Hash
          schema.transform_values{ |s| build(s) }
        when Scalar, Dictionary, Collection
          schema.class.new(
            values: build(schema.values),
            post_processors: schema.post_processors&.dup
          )
        when Struct
          new_schema = Struct.new(
            fields: schema.fields.map do |f|
              Field.new(
                f.name,
                build(f.type),
                f.opts.dup,
                post_processors: f.post_processors&.dup
              )
            end ,
            extra_fields: schema.extra_fields?,
            post_processors: schema.post_processors&.dup
          )

          if schema.extra_fields?
            standard_field_list = schema.fields.map(&:name)
            new_schema.transform do |value|
              if value.is_a?(Hash)
                extra_fields = value.except(*standard_field_list)
                standard_fields = value.slice(*standard_field_list)

                new_schema.dataclass.from_raw(
                  **standard_fields,
                  extra_fields:
                )
              else
                value
              end
            end
          else
            new_schema.transform do |value|
              if value.is_a?(Hash)
                new_schema.dataclass.from_raw(
                  **value
                )
              else
                value
              end
            end
          end
        when Selector
          Selector.new(
            values: build(schema.values),
            post_processors: schema.post_processors&.dup
          )
        else
          schema
        end
      end

    end
  end
end

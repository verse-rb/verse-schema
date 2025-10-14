## 1.2

- Add `Verse::Schema::Json.from` method to convert a Verse schema
to JSON Schema format (note: doesn't work the other way around yet)

## 1.1

- Add `strict` mode to `validate` which will raise an error if the input has
extra fields (in case of schema with extra_fields: false)
- Fix issue with query params by allowing coercion of String `'null'` into `nil` for `NilClass` field type

## 1.0

- First release of the Gem
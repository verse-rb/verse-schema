## 1.1

- Add `strict` mode to `validate` which will raise an error if the input has
extra fields (in case of schema with extra_fields: false)
- Fix issue with query params by allowing coercion of String `'null'` into `nil` for `NilClass` field type

## 1.0

- First release of the Gem
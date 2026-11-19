module pyrt

// untranslated_import reports a reference to an import outside the generated program.
pub fn untranslated_import(path string) !Value {
	return raise('ImportError', "untranslated Python import '${path}'")
}

module main

fn split_nul(payload string) []string {
	return payload.split('\x00')
}

fn strip_bell(line string) string {
	return line.replace('\x07', '')
}

fn has_vertical_tab(ch string) bool {
	return ch.contains('\x0b')
}

fn delimiter() string {
	return '\x1f'
}

fn unit_separator_fields(record string) []string {
	return record.split('\x1f')
}

fn main() {
	escape_8bit := 'ÿ'
	raw_text := 'plain text with no control characters'
}

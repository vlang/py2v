module main

fn flipped(symbol string) string {
	return py2v_ascii_swapcase1(symbol)
}

fn py2v_ascii_swapcase1(value string) string {
	mut bytes := value.bytes()
	for i, b in bytes {
		if b >= 128 { panic('py2v: swapcase of non-ASCII text is unsupported') }
		if b.is_letter() { bytes[i] = b ^ 32 }
	}
	return bytes.bytestr()
}

fn main() {
	println(flipped('PNbrqK 9!'))
	println(flipped(''))
}

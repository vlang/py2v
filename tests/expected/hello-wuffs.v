@[translated]
module main

type Any = bool | int | i64 | f64 | string | []byte

pub struct parser {
pub mut:
	val u32
}

fn test_parser(input Any, expected Any) {
	p := parser{
		val: u32(0)
	}
	result := p.parse(io.BytesIO(input))
	if result is Ok {
		assert result.value.value == expected.value
	}
}

fn main() {
	pytest.main([__file__])
	println('OK')
}

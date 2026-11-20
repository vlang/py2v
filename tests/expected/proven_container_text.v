module main

fn main() {
	println('[1, 2] [] {} ()')
	println('[\"a\'b\", \'a\"b\', \'a\\\'b\"c\', \'café\', \'雪\\n\', \'\\xa0\', \'\\u2028\']')
	println(('{\"a\'b\": [True, 1, None], \'雪\': (\'é\',)}').str() + ' ' + ("(1, 'a')").str() + ' ' + ('(1,)').str())
	println(('{1, 2}').str() + ' ' + ('set()').str() + ' ' + ("{'雪'}").str())
	println(('{}').str() + ' ' + ('[1, False, None]').str() + ' ' + ("(1, 'a')").str())
	println("[9223372036854775808, -0.0, [None, '雪']]")
}

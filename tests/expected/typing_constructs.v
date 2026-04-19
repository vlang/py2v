module main

type Any = bool | int | i64 | f64 | string | []u8

// NOTE: Union[int, string] — define: type X = int | string
fn process(x Any) ?string {
	return x
}

fn apply(f fn (int) string, x int) string {
	return f(x)
}

fn maybe(x ?int) string {
	return x
}

fn main() {
	result := process(42)
	println(result)
}

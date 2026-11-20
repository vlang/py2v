module main

import pyrt

type Any = pyrt.Value

// NOTE: Union[int, string] — define: type X = int | string
fn process(x Any) ?string {
	return x.str()
}

fn apply(f fn (int) string, x int) string {
	return f(x)
}

fn maybe(x ?int) string {
	return x.str()
}

fn main() {
	result := process(42)
	println(result)
}

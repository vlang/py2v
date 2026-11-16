module main

import pyrt

type Any = pyrt.Value

fn (a Any) + (b Any) Any {
	return pyrt.add(a, b) or { panic(err) }
}

fn (a Any) - (b Any) Any {
	return pyrt.sub(a, b) or { panic(err) }
}

fn (a Any) * (b Any) Any {
	return pyrt.mul(a, b) or { panic(err) }
}

fn (a Any) / (b Any) Any {
	return pyrt.truediv(a, b) or { panic(err) }
}

fn (a Any) % (b Any) Any {
	return pyrt.mod(a, b) or { panic(err) }
}

fn (a Any) < (b Any) bool {
	return pyrt.lt(a, b) or { panic(err) }
}

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

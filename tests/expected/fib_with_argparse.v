@[translated]
module main

pub struct Options {
pub mut:
	v bool
	n int
}

fn fib(i int) int {
	if i == 0 || i == 1 {
		return 1
	}

	return fib((i - 1)) + fib((i - 2))
}

fn main() {
	mut args := Options.parse_args()
	if args.v {
		println('args.v is true')
	}

	if args.n == 0 {
		args.n = 5
	}

	println((fib(args.n)).str())
}

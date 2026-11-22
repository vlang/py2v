module main

// TODO(py2v): no V equivalent for import argparse_dataclass
// Provide one in python_to_v_import (types.v) or port the module.

pub struct Options {
pub mut:
	v bool = false
	n int  = 0
}

fn fib(i int) int {
	if i == 0 || i == 1 {
		return 1
	}
	return py2v_integer_add1(fib(py2v_integer_sub1(i, 1, 'fib_with_argparse.py:15', 'subtraction')), fib(py2v_integer_sub1(i, 2, 'fib_with_argparse.py:15', 'subtraction')), 'fib_with_argparse.py:15', 'addition')
}

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_sub1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a < min + b) || (b < 0 && a > max + b) { py2v_integer_overflow1(site, operation) }
	return a - b
}

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}

fn main() {
	mut args := Options.parse_args()
	if args.v {
		println('args.v is true')
	}
	if args.n == 0 {
		args.n = 5
	}
	println(fib(args.n))
}

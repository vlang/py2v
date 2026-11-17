module main

import os

fn direct(path string) int {
	{
		mut source := os.open(path) or { panic(err) }
		defer { source.close() }
		return 11
	}
}

fn branch(path string, flag bool) int {
	{
		mut source := os.open(path) or { panic(err) }
		defer { source.close() }
		if flag {
			return 22
		}
		return 33
	}
}

fn nested(path string) int {
	{
		mut outer := os.open(path) or { panic(err) }
		defer { outer.close() }
		{
			mut inner := os.open(path) or { panic(err) }
			defer { inner.close() }
			return 44
		}
	}
}

fn following(path string) int {
	{
		mut source := os.open(path) or { panic(err) }
		defer { source.close() }
		// pass
	}
	return 55
}

fn main() {
	println(direct(os.args[0]))
	println(branch(os.args[0], true))
	println(branch(os.args[0], false))
	println(nested(os.args[0]))
	println(following(os.args[0]))
}

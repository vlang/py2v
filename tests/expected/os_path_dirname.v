module main

import os
import pyrt.pyos

fn hook_dirs() []string {
	return [pyos.path_dirname(@FILE)]
}

fn main() {
	println(hook_dirs().len)
	println('[' + pyos.path_dirname('file.txt') + ']')
	println(pyos.path_dirname('/a//b.txt'))
	println(pyos.path_dirname('/a/b/'))
}

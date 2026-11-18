module main

import os
import pyrt.pathlib
import pyrt.datetime
import pyrt

pub struct Path {
pub mut:
	value int = 3
}

pub struct Record {
pub mut:
	path     pathlib.Path       = pathlib.new_path('base')
	when     datetime.Datetime  = (datetime.new_datetime(2024, 1, 2) or { pyrt.fail(err) })
	duration datetime.Timedelta = (datetime.timedelta(days: 2) or { pyrt.fail(err) })
	paths    []pathlib.Path     = [pathlib.new_path('one')]
}

fn main() {
	record := Record{}
	println((record.path).str())
	println(record.when.isoformat())
	println(record.duration.total_seconds())
	println((record.paths[0]).str())
	local := Path{}
	println(local.value)
}

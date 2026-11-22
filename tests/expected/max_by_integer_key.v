module main

import pyrt

pub struct Entry {
pub mut:
	name  string
	score int
}

pub enum Rank {
	low  = 1
	high = 4
}

pub fn (member Rank) str() string {
	return match member {
		.low { 'Rank.LOW' }
		.high { 'Rank.HIGH' }
	}
}

pub fn (member Rank) py2v_enum_name() string {
	return match member {
		.low { 'LOW' }
		.high { 'HIGH' }
	}
}

pub fn Rank.py2v_enum_lookup(label string) !Rank {
	return match label {
		'LOW' { .low }
		'HIGH' { .high }
		else { return pyrt.key_error(pyrt.Value(label)) }
	}
}

fn (self Rank) points() int {
	return int(self)
}

fn winner_py(items []Entry) !Entry {
	return py2v_max_integer_key1[Entry](items, fn (entry Entry) int { return entry.score })!
}

fn highest_py(ranks []Rank) !Rank {
	return py2v_max_integer_key1[Rank](ranks, fn (rank Rank) int { return int(rank) })!
}

fn py2v_max_integer_key1[T](items []T, key fn (T) int) !T {
	if items.len == 0 { return pyrt.raise('ValueError', 'max() arg is an empty sequence') }
	mut best := items[0]
	mut best_key := key(best)
	for i in 1 .. items.len {
		item := items[i]
		item_key := key(item)
		if item_key > best_key {
			best = item
			best_key = item_key
		}
	}
	return best
}

fn py2v_distinct1[T](a []T) []T {
	mut b := []T{cap: a.len}
	for v in a {
		if v !in b {
			b << v
		}
	}
	return b
}

fn py2v_entry1() ! {
	println(winner_py([Entry{
		name:  'low'
		score: 1
	}, Entry{
		name:  'first'
		score: 4
	}, Entry{
		name:  'tied'
		score: 4
	}])!.name)
	println(highest_py(py2v_distinct1([Rank.high, Rank.low]))!.points())
	mut py2v_err_1 := ?IError(none)
	py2v_try_1: for {
		winner_py([]) or {
			py2v_err_1 = err
			break py2v_try_1
		}
		break
	}
	if py2v_raised_1 := py2v_err_1 {
		if pyrt.caught(py2v_raised_1, 'ValueError') != none {
			println('empty')
		} else {
			pyrt.fail(py2v_raised_1)
		}
	}
}

fn main() {
	py2v_entry1() or { pyrt.fail(err) }
}

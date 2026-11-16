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

pub struct Outcome {
pub mut:
	stop_reason ?string         = none
	meta        ?map[string]Any = none
	count       ?int            = none
}

fn describe(o Outcome, note ?string, extra Any) string {
	mut parts := []string{}
	if o.stop_reason != none && o.stop_reason != '' {
		parts << 'stopped:' + o.stop_reason
	}
	if !(o.meta != none && o.meta.len > 0) {
		parts << 'no-meta'
	}
	if o.count != none && o.count != 0 {
		parts << 'counted'
	}
	if note != none && note != '' {
		parts << 'note:' + note
	}
	if pyrt.truth(extra) {
		parts << 'extra'
	}
	if (o.stop_reason != none && o.stop_reason != '') && (note != none && note != '') {
		parts << 'both'
	}
	return parts.join(',')
}

fn main_func() {
	println(describe(Outcome{}, none, 0))
	println(describe(Outcome{
		stop_reason: 'limit'
		count:       0
	}, '', 'x'))
	println(describe(Outcome{
		stop_reason: ''
		meta:        {
			'a': 1
		}
		count:       3
	}, 'n', pyrt.empty_list()))
}

fn main() {
	main_func()
}

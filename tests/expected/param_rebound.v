module main

pub struct Counter {
pub mut:
	total int
}

fn (mut self Counter) init() {
	self.total = 0
}

fn (mut self Counter) add(py2v_amount_in5 int) int {
	mut amount := py2v_amount_in5
	if amount < 0 {
		amount = 0
	}
	self.total += amount
	return self.total
}

pub fn py2v_new_counter() Counter {
	mut py2v_instance := Counter{}
	py2v_instance.init()
	return py2v_instance
}

fn countdown(py2v_n_in1 int) int {
	mut n := py2v_n_in1
	mut steps := 0
	for n > 0 {
		n -= 1
		steps += 1
	}
	return steps
}

fn shout(py2v_text_in2 string, py2v_times_in3 int) string {
	mut text := py2v_text_in2
	mut times := py2v_times_in3
	text = text.to_upper()
	for times > 1 {
		text += '!'
		times -= 1
	}
	return text
}

fn clamp(py2v_x_in4 f64, lo f64) f64 {
	mut x := py2v_x_in4
	if x < lo {
		x = lo
	}
	return x
}

fn main() {
	value := 3
	println(countdown(value))
	println(value)
	println(shout('hi', 3))
	println(clamp(-1.5, 0))
	println(clamp(2.5, 0))
	mut c := py2v_new_counter()
	println(c.add(-4))
	println(c.add(5))
}

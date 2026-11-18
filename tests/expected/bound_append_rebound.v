module main

fn collect() []int {
	mut values := []int{}
	push := py2v_unsupported_bound_append_receiver_identity(values)
	values = [9]
	push(3)
	return values
}

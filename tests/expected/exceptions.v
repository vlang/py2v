@[translated]
module main

fn show() {
	// try {
	panic('Exception: ' + 'foo')
	// } catch {
	// except Exception:
	// NOTE: V does not have exception handling - this code is unreachable
	// println('caught')
	// finally:
	println('Finally')
	// }
	// try {
	panic('Exception: ' + 'foo')
	// } catch {
	// except:
	// NOTE: V does not have exception handling - this code is unreachable
	// println('Got it')
	// }
	// try {
	panic('Exception: ' + 'foo')
	// } catch {
	// except Exception:
	// NOTE: V does not have exception handling - this code is unreachable
	// assert e.str().contains('foo')
	// }
}

fn main() {
	show()
}

@[translated]
module main

fn show() {
	defer {
		println('Finally')
	}
	// try {
	panic('Exception: ' + 'foo')
	// } catch {
	// except Exception:
	// NOTE: V uses Result types (!) and or{} blocks instead of exceptions
	// println('caught')
	// }
	// try {
	panic('Exception: ' + 'foo')
	// } catch {
	// except:
	// NOTE: V uses Result types (!) and or{} blocks instead of exceptions
	// println('Got it')
	// }
	// try {
	panic('Exception: ' + 'foo')
	// } catch {
	// except Exception:
	// NOTE: V uses Result types (!) and or{} blocks instead of exceptions
	// assert e.str().contains('foo')
	// }
}

fn main() {
	show()
}

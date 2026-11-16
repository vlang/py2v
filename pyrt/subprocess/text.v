module subprocess

import pyrt

// stdout_text and stderr_text are a finished process's output where the call asked for
// text: the string itself, and an empty string where nothing was captured (Python has
// None there, which code that asked for text does not test for).
pub fn (p CompletedProcess) stdout_text() string {
	return stream_text(p.stdout)
}

pub fn (p CompletedProcess) stderr_text() string {
	return stream_text(p.stderr)
}

fn stream_text(v pyrt.Value) string {
	return match v {
		string { v }
		[]u8 { v.bytestr() }
		else { '' }
	}
}

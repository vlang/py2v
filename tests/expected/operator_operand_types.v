module main

pub struct Version {
pub mut:
	major int
}

fn (mut self Version) init(major int) {
	self.major = major
}

fn (self Version) < (other Version) bool {
	return self.major < other.major
}

fn (self Version) == (other Version) bool {
	return self.major == other.major
}

fn (self Version) + (other Version) Version {
	return py2v_new_version(self.major + other.major)
}

pub fn py2v_new_version(major int) Version {
	mut py2v_instance := Version{}
	py2v_instance.init(major)
	return py2v_instance
}

fn compare(a Version, b Version) bool {
	return a < b
}

fn add(a Version, b Version) Version {
	return a + b
}

fn main() {
	println(if compare(py2v_new_version(1), py2v_new_version(2)) { 'True' } else { 'False' })
	println(add(py2v_new_version(1), py2v_new_version(2)).major)
}

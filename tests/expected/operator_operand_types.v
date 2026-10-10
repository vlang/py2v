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
	return Version{
		major: self.major + other.major
	}
}

fn compare(a Version, b Version) bool {
	return a < b
}

fn add(a Version, b Version) Version {
	return a + b
}

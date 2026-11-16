module main

import pyrt.datetime
import pyrt

fn stamp_py() !string {
	start := datetime.new_datetime(2024, 1, 31, hour: 12, minute: 30, tzinfo: datetime.utc)!
	plain := datetime.new_datetime(2023, 12, 25)!
	return start.isoformat() + ' ' + plain.isoformat()
}

fn stamp() string {
	return stamp_py() or { pyrt.fail(err) }
}

fn age_seconds_py() !f64 {
	span := datetime.timedelta(days: 1, minutes: 90)!
	return span.total_seconds()
}

fn age_seconds() f64 {
	return age_seconds_py() or { pyrt.fail(err) }
}

fn main() {
	println(stamp())
	println(age_seconds())
	println((datetime.fromisoformat('2024-03-01T08:00:00') or { pyrt.fail(err) }).isoformat())
	println((datetime.timedelta(hours: 1, seconds: 5) or { pyrt.fail(err) }).total_seconds())
}

module main

import pyrt.datetime
import pyrt
import strconv

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

fn py2v_float_text1[T](value T) string {
	$if T is $float {
		scientific := strconv.f64_to_str(f64(value), 16)
		marker := scientific.index('e') or { return scientific.trim_left('+') }
		exponent := scientific[marker + 1..].int()
		if exponent < -4 || exponent >= 16 {
			return scientific
		}
		sign := if scientific.starts_with('-') { '-' } else { '' }
		digits := scientific[sign.len..marker].replace('.', '')
		point := exponent + 1
		if point <= 0 {
			return sign + '0.' + '0'.repeat(-point) + digits
		}
		if point >= digits.len {
			return sign + digits + '0'.repeat(point - digits.len) + '.0'
		}
		return sign + digits[..point] + '.' + digits[point..]
	} $else {
		return value.str()
	}
}

fn main() {
	println(stamp())
	println(py2v_float_text1(age_seconds()))
	println((datetime.fromisoformat('2024-03-01T08:00:00') or { pyrt.fail(err) }).isoformat())
	println(py2v_float_text1((datetime.timedelta(hours: 1, seconds: 5) or { pyrt.fail(err) }).total_seconds()))
}

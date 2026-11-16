module datetime

import pyrt

// A wall-clock time value. No fold or zoneinfo transition rules are modeled.
pub struct Time {
pub:
    hour int
    minute int
    second int
    microsecond int
    tzinfo ?Timezone
}

@[params]
pub struct TimeOptions {
pub:
    hour int
    minute int
    second int
    microsecond int
    tzinfo ?Timezone
}

@[params]
pub struct ReplaceOptions {
pub:
    year ?int
    month ?int
    day ?int
    hour ?int
    minute ?int
    second ?int
    microsecond ?int
    tzinfo ?Timezone
    // An omitted tzinfo preserves the old zone. Python tzinfo=None lowers to
    // clear_tzinfo: true. A non-None tzinfo simply replaces it.
    clear_tzinfo bool
}

@[params]
pub struct DateReplaceOptions {
pub:
    year ?int
    month ?int
    day ?int
}

pub fn new_time(opts TimeOptions) !Time {
    validate_time(opts.hour, opts.minute, opts.second, opts.microsecond)!
    return Time{hour: opts.hour, minute: opts.minute, second: opts.second,
        microsecond: opts.microsecond, tzinfo: opts.tzinfo}
}

pub fn (d Datetime) isoweekday() int { return d.weekday() + 1 }
pub fn (d Datetime) time() Time {
    // datetime.time() deliberately drops tzinfo; datetime.timetz() keeps it.
    return Time{hour: d.hour, minute: d.minute, second: d.second, microsecond: d.microsecond}
}
pub fn (d Datetime) timetz() Time {
    return Time{hour: d.hour, minute: d.minute, second: d.second,
        microsecond: d.microsecond, tzinfo: d.tzinfo}
}
pub fn (t Time) isoformat() string {
    mut out := pad(t.hour, 2) + ':' + pad(t.minute, 2) + ':' + pad(t.second, 2)
    if t.microsecond != 0 { out = out + '.' + pad(t.microsecond, 6) }
    if z := t.tzinfo { out = out + format_offset(z.offset_micros, true) }
    return out
}
pub fn (t Time) str() string { return t.isoformat() }
pub fn (t Time) utcoffset() ?Timedelta {
    if z := t.tzinfo { return z.utcoffset() }
    return none
}
pub fn (t Time) tzname() ?string {
    if z := t.tzinfo { return z.name }
    return none
}
pub fn (t Time) strftime(format string) !string {
    d := new_datetime(1900, 1, 1, hour: t.hour, minute: t.minute, second: t.second,
        microsecond: t.microsecond, tzinfo: t.tzinfo)!
    return d.strftime(format)!
}

pub fn (d Datetime) replace(opts ReplaceOptions) !Datetime {
    year := opts.year or { d.year }
    month := opts.month or { d.month }
    day := opts.day or { d.day }
    hour := opts.hour or { d.hour }
    minute := opts.minute or { d.minute }
    second := opts.second or { d.second }
    microsecond := opts.microsecond or { d.microsecond }
    mut zone := ZoneHolder{value: d.tzinfo}
    if opts.clear_tzinfo { zone.value = none }
    if z := opts.tzinfo { zone.value = z }
    return new_datetime(year, month, day, hour: hour, minute: minute, second: second,
        microsecond: microsecond, tzinfo: zone.value)!
}

pub fn (d Date) replace(opts DateReplaceOptions) !Date {
    return new_date(opts.year or { d.year }, opts.month or { d.month }, opts.day or { d.day })!
}

pub fn (d Datetime) subtract_delta(delta Timedelta) !Datetime { return d.add(delta.neg()!)! }
pub fn (d Datetime) eq(other Datetime) bool {
    if (d.tzinfo != none) != (other.tzinfo != none) { return false }
    result := d.compare(other) or { return false }
    return result == 0
}
pub fn (d Datetime) lt(other Datetime) !bool { return d.compare(other)! < 0 }
pub fn (d Datetime) le(other Datetime) !bool { return d.compare(other)! <= 0 }
pub fn (d Datetime) gt(other Datetime) !bool { return d.compare(other)! > 0 }
pub fn (d Datetime) ge(other Datetime) !bool { return d.compare(other)! >= 0 }
pub fn (d Datetime) bool_() bool { return true }

pub fn (d Date) add(delta Timedelta) !Date { return fromordinal(d.toordinal() + int(delta.days()))! }
pub fn (d Date) subtract_delta(delta Timedelta) !Date { return fromordinal(d.toordinal() - int(delta.days()))! }
pub fn (d Date) subtract(other Date) !Timedelta {
    return timedelta(days: i64(d.toordinal() - other.toordinal()))!
}
pub fn (d Date) eq(other Date) bool { return d.toordinal() == other.toordinal() }
pub fn (d Date) lt(other Date) bool { return d.toordinal() < other.toordinal() }
pub fn (d Date) le(other Date) bool { return d.toordinal() <= other.toordinal() }
pub fn (d Date) gt(other Date) bool { return d.toordinal() > other.toordinal() }
pub fn (d Date) ge(other Date) bool { return d.toordinal() >= other.toordinal() }
pub fn (d Date) bool_() bool { return true }

pub fn (td Timedelta) eq(other Timedelta) bool { return td.micros == other.micros }
pub fn (td Timedelta) lt(other Timedelta) bool { return td.micros < other.micros }
pub fn (td Timedelta) le(other Timedelta) bool { return td.micros <= other.micros }
pub fn (td Timedelta) gt(other Timedelta) bool { return td.micros > other.micros }
pub fn (td Timedelta) ge(other Timedelta) bool { return td.micros >= other.micros }
pub fn (td Timedelta) bool_() bool { return td.micros != 0 }
pub fn (td Timedelta) divide(other Timedelta) !f64 {
    if other.micros == 0 { return pyrt.raise('ZeroDivisionError', 'division by zero') }
    quotient := pyrt.truediv(pyrt.Value(td.micros), pyrt.Value(other.micros))!
    return pyrt.as_float(quotient)!
}
pub fn (td Timedelta) multiply(n i64) !Timedelta { return Timedelta{micros: checked_multiply(td.micros, n)!} }

fn time_micros(t Time) i64 {
    mut total := (i64(t.hour) * 3600 + i64(t.minute) * 60 + i64(t.second)) * micros_per_second + i64(t.microsecond)
    if z := t.tzinfo { total = total - z.offset_micros }
    return total
}
pub fn (t Time) eq(other Time) bool {
    if (t.tzinfo != none) != (other.tzinfo != none) { return false }
    return time_micros(t) == time_micros(other)
}
pub fn (t Time) compare(other Time) !int {
    if (t.tzinfo != none) != (other.tzinfo != none) {
        return pyrt.raise('TypeError', "can't compare offset-naive and offset-aware times")
    }
    a := time_micros(t)
    b := time_micros(other)
    return if a < b { -1 } else if a > b { 1 } else { 0 }
}
pub fn (t Time) lt(other Time) !bool { return t.compare(other)! < 0 }
pub fn (t Time) le(other Time) !bool { return t.compare(other)! <= 0 }
pub fn (t Time) gt(other Time) !bool { return t.compare(other)! > 0 }
pub fn (t Time) ge(other Time) !bool { return t.compare(other)! >= 0 }
pub fn (t Time) bool_() bool { return true }
pub fn (t Timezone) eq(other Timezone) bool { return t.offset_micros == other.offset_micros }

module datetime

import time
import pyrt

// Civil calendar and epoch calculations are independent of time.Time's private
// fields. Datetime is a wall-clock tuple, NOT a timezone-transition database.
const micros_per_second = i64(1000000)
const micros_per_day = i64(86400000000)
const epoch_ordinal = 719163
const weekday_short = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
const weekday_long = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
const month_short = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
const month_long = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']

pub struct Timezone {
pub:
    offset_seconds int
    offset_micros  i64
    name           string
}

pub const utc = Timezone{offset_seconds: 0, offset_micros: 0, name: 'UTC'}

pub struct Timedelta {
    micros i64
}

pub struct Date {
pub:
    year int
    month int
    day int
}

struct ZoneHolder {
mut:
    value ?Timezone
}

pub struct Datetime {
pub:
    year        int
    month       int
    day         int
    hour        int
    minute      int
    second      int
    microsecond int
    tzinfo      ?Timezone
}

@[params]
pub struct DateTimeOptions {
pub:
    hour int
    minute int
    second int
    microsecond int
    tzinfo ?Timezone
}

@[params]
pub struct TimedeltaOptions {
pub:
    weeks i64
    days i64
    hours i64
    minutes i64
    seconds i64
    milliseconds i64
    microseconds i64
}

@[params]
pub struct NowOptions {
pub:
    tzinfo ?Timezone
}

@[params]
pub struct FromTimestampOptions {
pub:
    tzinfo ?Timezone
}

fn pad(n int, width int) string {
    mut t := n.str()
    for t.len < width { t = '0' + t }
    return t
}

fn parse_digits(s string, begin int, count int) !int {
    if begin < 0 || count < 1 || begin + count > s.len { return pyrt.raise('ValueError', 'Invalid isoformat string: ${pyrt.repr(pyrt.Value(s))}') }
    mut value := 0
    for i in begin .. begin + count {
        if s[i] < 48 || s[i] > 57 { return pyrt.raise('ValueError', 'Invalid isoformat string: ${pyrt.repr(pyrt.Value(s))}') }
        value = value * 10 + int(s[i] - 48)
    }
    return value
}

fn leap(year int) bool {
    return year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}

fn days_in_month(year int, month int) int {
    if month == 2 { return if leap(year) { 29 } else { 28 } }
    if month == 4 || month == 6 || month == 9 || month == 11 { return 30 }
    return 31
}

fn validate_date(year int, month int, day int) ! {
    if year < 1 || year > 9999 { return pyrt.raise('ValueError', 'year must be in 1..9999') }
    if month < 1 || month > 12 { return pyrt.raise('ValueError', 'month must be in 1..12') }
    if day < 1 || day > days_in_month(year, month) { return pyrt.raise('ValueError', 'day is out of range for month') }
}

fn validate_time(hour int, minute int, second int, microsecond int) ! {
    if hour < 0 || hour > 23 { return pyrt.raise('ValueError', 'hour must be in 0..23') }
    if minute < 0 || minute > 59 { return pyrt.raise('ValueError', 'minute must be in 0..59') }
    if second < 0 || second > 59 { return pyrt.raise('ValueError', 'second must be in 0..59') }
    if microsecond < 0 || microsecond > 999999 { return pyrt.raise('ValueError', 'microsecond must be in 0..999999') }
}

pub fn new_date(year int, month int, day int) !Date {
    validate_date(year, month, day)!
    return Date{year: year, month: month, day: day}
}

pub fn new_datetime(year int, month int, day int, opts DateTimeOptions) !Datetime {
    validate_date(year, month, day)!
    validate_time(opts.hour, opts.minute, opts.second, opts.microsecond)!
    return Datetime{year: year, month: month, day: day, hour: opts.hour, minute: opts.minute,
        second: opts.second, microsecond: opts.microsecond, tzinfo: opts.tzinfo}
}

// Gregorian ordinal: 0001-01-01 is ordinal 1, as in Python.
fn ordinal(year int, month int, day int) int {
    prev := year - 1
    mut total := prev * 365 + prev / 4 - prev / 100 + prev / 400 + day
    for m in 1 .. month { total = total + days_in_month(year, m) }
    return total
}

pub fn fromordinal(n int) !Date {
    if n < 1 || n > 3652059 { return pyrt.raise('ValueError', 'ordinal must be >= 1') }
    mut lo := 1
    mut hi := 10000
    for lo + 1 < hi {
        mid := (lo + hi) / 2
        if ordinal(mid, 1, 1) <= n { lo = mid } else { hi = mid }
    }
    mut month := 1
    mut remain := n - ordinal(lo, 1, 1)
    for month < 12 {
        size := days_in_month(lo, month)
        if remain < size { break }
        remain = remain - size
        month = month + 1
    }
    return Date{year: lo, month: month, day: remain + 1}
}

pub fn (d Date) toordinal() int { return ordinal(d.year, d.month, d.day) }
pub fn (d Date) weekday() int { return (d.toordinal() - 1) % 7 }
pub fn (d Date) isoweekday() int { return d.weekday() + 1 }
pub fn (d Date) isoformat() string { return '${pad(d.year, 4)}-${pad(d.month, 2)}-${pad(d.day, 2)}' }
pub fn (d Date) str() string { return d.isoformat() }
pub fn (d Date) year_day() int { return d.toordinal() - ordinal(d.year, 1, 1) + 1 }

pub fn (d Datetime) date() Date { return Date{year: d.year, month: d.month, day: d.day} }
pub fn (d Datetime) weekday() int { return d.date().weekday() }
pub fn (d Datetime) toordinal() int { return d.date().toordinal() }
pub fn (d Datetime) year_day() int { return d.date().year_day() }

fn format_offset(micros i64, colon bool) string {
    mut n := micros
    sign := if n >= 0 { '+' } else { '-' }
    if n < 0 { n = -n }
    seconds := n / micros_per_second
    fractional := n % micros_per_second
    mut s := '${sign}${pad(int(seconds / 3600), 2)}'
    if colon { s = s + ':' }
    s = s + pad(int((seconds % 3600) / 60), 2)
    if seconds % 60 != 0 || fractional != 0 {
        if colon { s = s + ':' }
        s = s + pad(int(seconds % 60), 2)
        if fractional != 0 { s = s + '.' + pad(int(fractional), 6) }
    }
    return s
}

pub fn timezone(offset Timedelta, name string) !Timezone {
    if offset.micros <= -micros_per_day || offset.micros >= micros_per_day {
        return pyrt.raise('ValueError', 'offset must be a timedelta strictly between -timedelta(hours=24) and timedelta(hours=24)')
    }
    seconds := int(offset.micros / micros_per_second)
    if offset.micros == 0 && name == '' { return utc }
    zone_name := if name == '' { 'UTC' + format_offset(offset.micros, true) } else { name }
    return Timezone{offset_seconds: seconds, offset_micros: offset.micros, name: zone_name}
}

pub fn (z Timezone) utcoffset() Timedelta { return Timedelta{micros: z.offset_micros} }
pub fn (z Timezone) tzname() string { return z.name }
pub fn (z Timezone) str() string { return z.name }

fn micros_of_day(d Datetime) i64 {
    return (i64(d.hour) * 3600 + i64(d.minute) * 60 + i64(d.second)) * micros_per_second + i64(d.microsecond)
}

pub fn (d Datetime) isoformat() string {
    mut s := d.date().isoformat() + 'T' + pad(d.hour, 2) + ':' + pad(d.minute, 2) + ':' + pad(d.second, 2)
    if d.microsecond != 0 { s = s + '.' + pad(d.microsecond, 6) }
    if z := d.tzinfo { s = s + format_offset(z.offset_micros, true) }
    return s
}

pub fn (d Datetime) isoformat_sep(sep string) !string {
    if sep.runes().len != 1 { return pyrt.raise('TypeError', 'isoformat() argument 1 must be a unicode character, not str') }
    s := d.isoformat()
    return s[0 .. 10] + sep + s[11 .. s.len]
}

pub fn (d Datetime) str() string {
    s := d.isoformat()
    return s[0 .. 10] + ' ' + s[11 .. s.len]
}

fn format_directive(d Datetime, directive u8) !string {
    return match directive {
        89 { pad(d.year, 4) }
        121 { pad(d.year % 100, 2) }
        109 { pad(d.month, 2) }
        100 { pad(d.day, 2) }
        72 { pad(d.hour, 2) }
        77 { pad(d.minute, 2) }
        83 { pad(d.second, 2) }
        102 { pad(d.microsecond, 6) }
        122 { if z := d.tzinfo { format_offset(z.offset_micros, false) } else { '' } }
        90 { if z := d.tzinfo { z.name } else { '' } }
        106 { pad(d.year_day(), 3) }
        97 { weekday_short[d.weekday()] }
        65 { weekday_long[d.weekday()] }
        98 { month_short[d.month - 1] }
        66 { month_long[d.month - 1] }
        112 { if d.hour < 12 { 'AM' } else { 'PM' } }
        73 { pad(if d.hour % 12 == 0 { 12 } else { d.hour % 12 }, 2) }
        37 { '%' }
        else { return pyrt.raise('ValueError', 'unsupported strftime directive') }
    }
}

pub fn (d Datetime) strftime(fmt string) !string {
    mut s := ''
    mut i := 0
    for i < fmt.len {
        if fmt[i] == 37 {
            if i + 1 >= fmt.len { return pyrt.raise('ValueError', 'stray % in format') }
            s = s + format_directive(d, fmt[i + 1])!
            i = i + 2
        } else {
            s = s + fmt[i .. i + 1]
            i = i + 1
        }
    }
    return s
}

pub fn (d Date) strftime(fmt string) !string {
    dt := Datetime{year: d.year, month: d.month, day: d.day}
    return dt.strftime(fmt)!
}

// Strict civil-format parsing, with a deliberately finite subset of CPython's
// 3.11+ ISO extensions. Unsupported forms raise ValueError, not a guessed date.
fn parse_iso_date(text string) !Date {
    if text.len == 10 && text[4] == 45 && text[7] == 45 {
        return new_date(parse_digits(text, 0, 4)!, parse_digits(text, 5, 2)!, parse_digits(text, 8, 2)!)!
    }
    if text.len == 8 {
        return new_date(parse_digits(text, 0, 4)!, parse_digits(text, 4, 2)!, parse_digits(text, 6, 2)!)!
    }
    return pyrt.raise('ValueError', 'Invalid isoformat string: ${pyrt.repr(pyrt.Value(text))}')
}

pub fn date_fromisoformat(text string) !Date { return parse_iso_date(text)! }

fn parse_iso_clock(text string) !Datetime {
    // This helper returns time components in an otherwise empty Datetime.
    mut end := text.len
    mut zone := ZoneHolder{}
    if end > 0 && (text[end - 1] == 90 || text[end - 1] == 122) {
        zone.value = utc
        end = end - 1
    } else {
        mut sign_pos := -1
        for i in 1 .. end {
            if text[i] == 43 || text[i] == 45 { sign_pos = i }
        }
        if sign_pos >= 0 {
            offset := text[sign_pos .. end]
            mut compact := ''
            mut fractional := ''
            mut in_fraction := false
            for k in 1 .. offset.len {
                if offset[k] == 46 || offset[k] == 44 { in_fraction = true; continue }
                if offset[k] == 58 { continue }
                if in_fraction { fractional = fractional + offset[k .. k + 1] }
                else { compact = compact + offset[k .. k + 1] }
            }
            if compact.len != 2 && compact.len != 4 && compact.len != 6 {
                return pyrt.raise('ValueError', 'Invalid isoformat string: ${pyrt.repr(pyrt.Value(text))}')
            }
            hours := parse_digits(compact, 0, 2)!
            minutes := if compact.len >= 4 { parse_digits(compact, 2, 2)! } else { 0 }
            seconds := if compact.len >= 6 { parse_digits(compact, 4, 2)! } else { 0 }
            if hours > 23 || minutes > 59 || seconds > 59 { return pyrt.raise('ValueError', 'Invalid isoformat string: ${pyrt.repr(pyrt.Value(text))}') }
            mut frac := 0
            if fractional.len > 0 {
                mut digits := fractional
                if digits.len > 6 { digits = digits[0 .. 6] }
                for digits.len < 6 { digits = digits + '0' }
                frac = parse_digits(digits, 0, 6)!
            }
            sign := if offset[0] == 45 { -1 } else { 1 }
            signed := (hours * 3600 + minutes * 60 + seconds) * sign
            offset_us := (i64(hours * 3600 + minutes * 60 + seconds) * micros_per_second + i64(frac)) * i64(sign)
            zone.value = Timezone{offset_seconds: signed, offset_micros: offset_us, name: if offset_us == 0 { 'UTC' } else { 'UTC' + format_offset(offset_us, true) }}
            end = sign_pos
        }
    }
    clock := text[0 .. end]
    mut raw := ''
    mut fractional := ''
    mut fraction := false
    for k in 0 .. clock.len {
        b := clock[k]
        if b == 46 || b == 44 { fraction = true; continue }
        if b == 58 { continue }
        if fraction { fractional = fractional + clock[k .. k + 1] } else { raw = raw + clock[k .. k + 1] }
    }
    if raw.len != 2 && raw.len != 4 && raw.len != 6 { return pyrt.raise('ValueError', 'Invalid isoformat string: ${pyrt.repr(pyrt.Value(text))}') }
    mut micros := 0
    if fractional.len > 0 {
        for k in 0 .. fractional.len { b := fractional[k]; if b < 48 || b > 57 { return pyrt.raise('ValueError', 'Invalid isoformat string: ${pyrt.repr(pyrt.Value(text))}') } }
        mut digits := fractional
        if digits.len > 6 { digits = digits[0 .. 6] }
        for digits.len < 6 { digits = digits + '0' }
        micros = parse_digits(digits, 0, 6)!
    }
    return Datetime{hour: parse_digits(raw, 0, 2)!, minute: if raw.len >= 4 { parse_digits(raw, 2, 2)! } else { 0 },
        second: if raw.len >= 6 { parse_digits(raw, 4, 2)! } else { 0 }, microsecond: micros, tzinfo: zone.value}
}

pub fn fromisoformat(text string) !Datetime {
    if text.len < 8 { return pyrt.raise('ValueError', 'Invalid isoformat string: ${pyrt.repr(pyrt.Value(text))}') }
    date_width := if text.len >= 10 && text[4] == 45 { 10 } else { 8 }
    if text.len < date_width { return pyrt.raise('ValueError', 'Invalid isoformat string: ${pyrt.repr(pyrt.Value(text))}') }
    date := parse_iso_date(text[0 .. date_width]) or { return pyrt.raise('ValueError', 'Invalid isoformat string: ${pyrt.repr(pyrt.Value(text))}') }
    if text.len == date_width { return Datetime{year: date.year, month: date.month, day: date.day} }
    // Python accepts an arbitrary one-codepoint separator; this restricted
    // implementation accepts T, t, and ASCII space.
    if text[date_width] != 84 && text[date_width] != 116 && text[date_width] != 32 { return pyrt.raise('ValueError', 'Invalid isoformat string: ${pyrt.repr(pyrt.Value(text))}') }
    parts := parse_iso_clock(text[date_width + 1 .. text.len])!
    return new_datetime(date.year, date.month, date.day, hour: parts.hour, minute: parts.minute,
        second: parts.second, microsecond: parts.microsecond, tzinfo: parts.tzinfo)!
}

fn checked_add(a i64, b i64) !i64 {
    top := i64(9223372036854775807)
    bottom := i64(-9223372036854775807) - 1
    if (b > 0 && a > top - b) || (b < 0 && a < bottom - b) { return pyrt.raise('OverflowError', 'timedelta is too large') }
    return a + b
}

fn checked_multiply(a i64, b i64) !i64 {
    if b == 0 { return 0 }
    max_value := i64(9223372036854775807)
    min_value := i64(-9223372036854775807) - 1
    if a > 0 && b > 0 && a > max_value / b { return pyrt.raise('OverflowError', 'timedelta is too large') }
    if a < 0 && b > 0 && a < min_value / b { return pyrt.raise('OverflowError', 'timedelta is too large') }
    if a > 0 && b < 0 && b < min_value / a { return pyrt.raise('OverflowError', 'timedelta is too large') }
    if a < 0 && b < 0 && a < max_value / b { return pyrt.raise('OverflowError', 'timedelta is too large') }
    return a * b
}

pub fn timedelta(opts TimedeltaOptions) !Timedelta {
    days := checked_add(checked_multiply(opts.weeks, 7)!, opts.days)!
    mut total := checked_multiply(days, micros_per_day)!
    total = checked_add(total, checked_multiply(opts.hours, i64(3600000000))!)!
    total = checked_add(total, checked_multiply(opts.minutes, i64(60000000))!)!
    total = checked_add(total, checked_multiply(opts.seconds, micros_per_second)!)!
    total = checked_add(total, checked_multiply(opts.milliseconds, 1000)!)!
    total = checked_add(total, opts.microseconds)!
    return Timedelta{micros: total}
}

pub fn (td Timedelta) total_seconds() f64 { return f64(td.micros) / 1000000.0 }
pub fn (td Timedelta) total_microseconds() i64 { return td.micros }

fn divmod_floor(a i64, b i64) (i64, i64) {
    mut q := a / b
    mut r := a % b
    if r < 0 { q = q - 1; r = r + b }
    return q, r
}

pub fn (td Timedelta) days() i64 {
    q, _ := divmod_floor(td.micros, micros_per_day)
    return q
}
pub fn (td Timedelta) seconds() int {
    _, r := divmod_floor(td.micros, micros_per_day)
    return int(r / micros_per_second)
}
pub fn (td Timedelta) microseconds() int {
    _, r := divmod_floor(td.micros, micros_per_second)
    return int(r)
}

pub fn (td Timedelta) str() string {
    days := td.days()
    sec := td.seconds()
    hours := sec / 3600
    minutes := (sec % 3600) / 60
    seconds := sec % 60
    mut s := '${hours}:${pad(minutes, 2)}:${pad(seconds, 2)}'
    if td.microseconds() != 0 { s = s + '.' + pad(td.microseconds(), 6) }
    if days == 1 { return '1 day, ' + s }
    if days != 0 { return '${days} day' + (if days == 1 || days == -1 { '' } else { 's' }) + ', ' + s }
    return s
}

pub fn (td Timedelta) add(other Timedelta) !Timedelta {
    return Timedelta{micros: checked_add(td.micros, other.micros)!}
}
pub fn (td Timedelta) neg() !Timedelta {
    return Timedelta{micros: checked_multiply(td.micros, -1)!}
}
pub fn (td Timedelta) subtract(other Timedelta) !Timedelta {
    return td.add(other.neg()!)!
}

fn utc_micros(d Datetime) !i64 {
    mut offset := i64(0)
    if z := d.tzinfo { offset = z.offset_micros }
    return (i64(d.toordinal()) - epoch_ordinal) * micros_per_day + micros_of_day(d) - offset
}

pub fn (d Datetime) timestamp() !f64 {
    // Naive timestamps currently interpret wall time as UTC. This intentionally
    // differs from Python's local-zone mktime including historical DST.
    return f64(utc_micros(d)!) / 1000000.0
}

pub fn (d Datetime) utcoffset() ?Timedelta {
    if z := d.tzinfo { return z.utcoffset() }
    return none
}

pub fn (d Datetime) tzname() ?string {
    if z := d.tzinfo { return z.name }
    return none
}

pub fn (d Datetime) add(delta Timedelta) !Datetime {
    micros := checked_add((i64(d.toordinal()) - 1) * micros_per_day + micros_of_day(d), delta.micros)!
    days, day_micro := divmod_floor(micros, micros_per_day)
    date := fromordinal(int(days + 1))!
    return Datetime{year: date.year, month: date.month, day: date.day,
        hour: int(day_micro / i64(3600000000)), minute: int((day_micro / i64(60000000)) % 60),
        second: int((day_micro / micros_per_second) % 60), microsecond: int(day_micro % micros_per_second),
        tzinfo: d.tzinfo}
}

pub fn (d Datetime) subtract(other Datetime) !Timedelta {
    aware := d.tzinfo != none
    if aware != (other.tzinfo != none) { return pyrt.raise('TypeError', "can't subtract offset-naive and offset-aware datetimes") }
    return Timedelta{micros: utc_micros(d)! - utc_micros(other)!}
}

pub fn (d Datetime) compare(other Datetime) !int {
    if (d.tzinfo != none) != (other.tzinfo != none) {
        return pyrt.raise('TypeError', "can't compare offset-naive and offset-aware datetimes")
    }
    a := utc_micros(d)!
    b := utc_micros(other)!
    return if a < b { -1 } else if a > b { 1 } else { 0 }
}

fn from_utc_micro(micros i64, zone ?Timezone) !Datetime {
    mut shifted := micros
    if z := zone { shifted = checked_add(micros, z.offset_micros)! }
    days, day_micro := divmod_floor(shifted, micros_per_day)
    date := fromordinal(int(days + epoch_ordinal))!
    return Datetime{year: date.year, month: date.month, day: date.day,
        hour: int(day_micro / i64(3600000000)), minute: int((day_micro / i64(60000000)) % 60),
        second: int((day_micro / micros_per_second) % 60), microsecond: int(day_micro % micros_per_second),
        tzinfo: zone}
}

fn from_local_micro(micros i64) !Datetime {
    // The V Time formatter uses the machine's LOCAL zone for the target epoch.
    local := time.unix_micro(micros).local().strftime('%Y%m%d%H%M%S')
    if local.len != 14 { return from_utc_micro(micros, none)! }
    mut fractional := micros % micros_per_second
    if fractional < 0 { fractional = fractional + micros_per_second }
    return new_datetime(parse_digits(local, 0, 4)!, parse_digits(local, 4, 2)!, parse_digits(local, 6, 2)!,
        hour: parse_digits(local, 8, 2)!, minute: parse_digits(local, 10, 2)!, second: parse_digits(local, 12, 2)!, microsecond: int(fractional))!
}

pub fn fromtimestamp(ts f64, opts FromTimestampOptions) !Datetime {
    if ts != ts || ts >= 253402300800.0 || ts < -62135596800.0 {
        return pyrt.raise('OverflowError', 'timestamp out of range for datetime')
    }
    micros := i64(ts * 1000000.0)
    if z := opts.tzinfo { return from_utc_micro(micros, z)! }
    return from_local_micro(micros)!
}

pub fn now(opts NowOptions) !Datetime {
    current := time.now().unix_micro()
    if z := opts.tzinfo { return from_utc_micro(current, z)! }
    return from_local_micro(current)!
}

pub fn utcnow() !Datetime {
    return from_utc_micro(time.now().unix_micro(), none)!
}

pub fn (d Datetime) astimezone(zone Timezone) !Datetime {
    if d.tzinfo == none { return pyrt.raise('ValueError', 'astimezone() requires an aware datetime in this runtime') }
    return from_utc_micro(utc_micros(d)!, zone)!
}

// strptime supports the directive set requested; it intentionally does not
// use time.parse_format, whose directives/error wording differ from Python.
fn starts_at(s string, pos int, wanted string) bool {
    return pos >= 0 && pos + wanted.len <= s.len && s[pos .. pos + wanted.len] == wanted
}

struct ParsedNumber {
    value int
    pos int
}

fn parsed_number(text string, pos int, max_digits int, min_digits int) !ParsedNumber {
    mut i := pos
    mut value := 0
    for i < text.len && i < pos + max_digits && text[i] >= 48 && text[i] <= 57 {
        value = value * 10 + int(text[i] - 48)
        i = i + 1
    }
    if i - pos < min_digits { return pyrt.raise('ValueError', 'time data does not match format') }
    return ParsedNumber{value: value, pos: i}
}

pub fn strptime(text string, fmt string) !Datetime {
    mut y := 1900
    mut mo := 1
    mut day := 1
    mut hour := 0
    mut minute := 0
    mut second := 0
    mut micro := 0
    mut day_of_year := 0
    mut ampm := -1
    mut twelve_hour := false
    mut tz := ZoneHolder{}
    mut i := 0
    mut j := 0
    for j < fmt.len {
        if fmt[j] != 37 {
            if i >= text.len || fmt[j] != text[i] { return pyrt.raise('ValueError', "time data '${text}' does not match format '${fmt}'") }
            i = i + 1; j = j + 1
            continue
        }
        j = j + 1
        if j >= fmt.len { return pyrt.raise('ValueError', 'stray % in format') }
        directive := fmt[j]
        j = j + 1
        match directive {
            89, 121, 109, 100, 72, 73, 77, 83, 102, 106 {
                parsed := parsed_number(text, i, if directive == 89 { 4 } else if directive == 102 { 6 } else if directive == 106 { 3 } else { 2 }, 1)!
                n := parsed.value
                end := parsed.pos
                if directive == 89 { y = n }
                if directive == 121 { y = if n >= 69 { 1900 + n } else { 2000 + n } }
                if directive == 109 { mo = n }
                if directive == 100 { day = n }
                if directive == 72 || directive == 73 { hour = n; twelve_hour = directive == 73 }
                if directive == 77 { minute = n }
                if directive == 83 { second = n }
                if directive == 106 { day_of_year = n }
                if directive == 102 {
                    micro = n
                    missing_digits := 6 - (end - i)
                    for _ in 0 .. missing_digits { micro = micro * 10 }
                }
                i = end
            }
            97, 65, 98, 66, 112 {
                mut found := false
                if directive == 112 {
                    if starts_at(text, i, 'AM') { ampm = 0; i = i + 2; found = true }
                    if !found && starts_at(text, i, 'PM') { ampm = 1; i = i + 2; found = true }
                } else {
                    choices := if directive == 97 { weekday_short } else if directive == 65 { weekday_long } else if directive == 98 { month_short } else { month_long }
                    for idx, name in choices {
                        if starts_at(text, i, name) { i = i + name.len; found = true; if directive == 98 || directive == 66 { mo = idx + 1 }; break }
                    }
                }
                if !found { return pyrt.raise('ValueError', "time data '${text}' does not match format '${fmt}'") }
            }
            122 {
                if i >= text.len { return pyrt.raise('ValueError', 'time data does not match format') }
                if text[i] == 90 { tz.value = utc; i = i + 1 }
                else {
                    sign := if text[i] == 45 { -1 } else { 1 }
                    if text[i] != 43 && text[i] != 45 { return pyrt.raise('ValueError', 'time data does not match format') }
                    i = i + 1
                    hour_part := parsed_number(text, i, 2, 2)!
                    hh := hour_part.value
                    i = hour_part.pos
                    if i < text.len && text[i] == 58 { i = i + 1 }
                    minute_part := parsed_number(text, i, 2, 2)!
                    mm := minute_part.value
                    i = minute_part.pos
                    if hh >= 24 || mm >= 60 { return pyrt.raise('ValueError', 'time data does not match format') }
                    offset := sign * (hh * 3600 + mm * 60)
                    tz.value = Timezone{offset_seconds: offset, offset_micros: i64(offset) * micros_per_second, name: if offset == 0 { 'UTC' } else { 'UTC' + format_offset(i64(offset) * micros_per_second, true) }}
                }
            }
            90 {
                if starts_at(text, i, 'UTC') { tz.value = utc; i = i + 3 }
                else if starts_at(text, i, 'GMT') { tz.value = utc; i = i + 3 }
                else { return pyrt.raise('ValueError', 'time data does not match format') }
            }
            37 { if i >= text.len || text[i] != 37 { return pyrt.raise('ValueError', 'time data does not match format') }; i = i + 1 }
            else { return pyrt.raise('ValueError', 'unsupported strptime directive') }
        }
    }
    if i != text.len { return pyrt.raise('ValueError', 'unconverted data remains: ${text[i .. text.len]}') }
    if twelve_hour {
        if hour < 1 || hour > 12 { return pyrt.raise('ValueError', 'hour must be in 1..12') }
        hour = hour % 12
        if ampm == 1 { hour = hour + 12 }
    }
    if day_of_year > 0 {
        if day_of_year > (if leap(y) { 366 } else { 365 }) { return pyrt.raise('ValueError', 'day of year out of range') }
        d := fromordinal(ordinal(y, 1, 1) + day_of_year - 1)!
        mo = d.month; day = d.day
    }
    return new_datetime(y, mo, day, hour: hour, minute: minute, second: second, microsecond: micro, tzinfo: tz.value)!
}

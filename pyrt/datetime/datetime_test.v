module datetime

import pyrt

fn test_date_calendar() {
    d := new_date(2024, 2, 29) or { panic(err.msg()) }
    // python: __import__('datetime').date(2024, 2, 29).isoformat() == '2024-02-29'
    assert d.isoformat() == '2024-02-29'
    // python: __import__('datetime').date(2024, 2, 29).toordinal() == 738945
    assert d.toordinal() == 738945
    // python: __import__('datetime').date.fromordinal(738945).isoformat() == '2024-02-29'
    assert (fromordinal(738945) or { panic(err.msg()) }).isoformat() == '2024-02-29'
    // python: __import__('datetime').date(2000, 1, 1).weekday() == 5
    assert (new_date(2000, 1, 1) or { panic(err.msg()) }).weekday() == 5
    // python: __import__('datetime').date(2000, 1, 1).isoweekday() == 6
    assert (new_date(2000, 1, 1) or { panic(err.msg()) }).isoweekday() == 6
    // python: __import__('datetime').date.fromisoformat('20241114').isoformat() == '2024-11-14'
    assert (date_fromisoformat('20241114') or { panic(err.msg()) }).str() == '2024-11-14'
    // python: str(__import__('datetime').date(2023, 12, 31)) == '2023-12-31'
    assert (new_date(2023, 12, 31) or { panic(err.msg()) }).str() == '2023-12-31'
    // python: __import__('datetime').date(2024, 1, 1).strftime('%Y/%m/%d (%a)') == '2024/01/01 (Mon)'
    assert ((new_date(2024, 1, 1) or { panic(err.msg()) }).strftime('%Y/%m/%d (%a)') or { panic(err.msg()) }) == '2024/01/01 (Mon)'
    // python: str(__import__('datetime').date(1, 1, 1)) == '0001-01-01'
    assert (new_date(1, 1, 1) or { panic(err.msg()) }).str() == '0001-01-01'
    // python: __import__('datetime').date.max.toordinal() == 3652059
    assert (new_date(9999, 12, 31) or { panic(err.msg()) }).toordinal() == 3652059
    // python: __import__('datetime').date(2024, 2, 29).timetuple().tm_yday == 60
    assert d.year_day() == 60
}

fn test_iso_and_format() {
    d := fromisoformat('2024-02-29T23:04:05.000123+05:30') or { panic(err.msg()) }
    // python: __import__('datetime').datetime.fromisoformat('2024-02-29T23:04:05.000123+05:30').isoformat() == '2024-02-29T23:04:05.000123+05:30'
    assert d.isoformat() == '2024-02-29T23:04:05.000123+05:30'
    // python: str(__import__('datetime').datetime.fromisoformat('2024-02-29T23:04:05.000123+05:30')) == '2024-02-29 23:04:05.000123+05:30'
    assert d.str() == '2024-02-29 23:04:05.000123+05:30'
    // python: __import__('datetime').datetime.fromisoformat('2024-02-29T23:04:05.000123+05:30').strftime('%Y/%m/%d %H:%M:%S.%f %z %Z') == '2024/02/29 23:04:05.000123 +0530 UTC+05:30'
    assert (d.strftime('%Y/%m/%d %H:%M:%S.%f %z %Z') or { panic(err.msg()) }) == '2024/02/29 23:04:05.000123 +0530 UTC+05:30'
    // python: __import__('datetime').datetime(2023, 8, 4, 0, 5).strftime('%a %A %b %B %p %I %j %y %%') == 'Fri Friday Aug August AM 12 216 23 %'
    d2 := new_datetime(2023, 8, 4, minute: 5) or { panic(err.msg()) }
    assert (d2.strftime('%a %A %b %B %p %I %j %y %%') or { panic(err.msg()) }) == 'Fri Friday Aug August AM 12 216 23 %'
    // python: __import__('datetime').datetime(2024, 3, 1, 15, 4, 5).isoformat() == '2024-03-01T15:04:05'
    d3 := new_datetime(2024, 3, 1, hour: 15, minute: 4, second: 5) or { panic(err.msg()) }
    assert d3.isoformat() == '2024-03-01T15:04:05'
    // python: __import__('datetime').datetime(2024, 3, 1, 15, 4, 5).isoformat(' ') == '2024-03-01 15:04:05'
    assert (d3.isoformat_sep(' ') or { panic(err.msg()) }) == '2024-03-01 15:04:05'
    // python: __import__('datetime').datetime.fromisoformat('2024-03-01T15:04:05Z').isoformat() == '2024-03-01T15:04:05+00:00'
    assert (fromisoformat('2024-03-01T15:04:05Z') or { panic(err.msg()) }).isoformat() == '2024-03-01T15:04:05+00:00'
    // python: __import__('datetime').datetime.fromisoformat('2024-03-01 15:04:05').isoformat() == '2024-03-01T15:04:05'
    assert (fromisoformat('2024-03-01 15:04:05') or { panic(err.msg()) }).isoformat() == '2024-03-01T15:04:05'
    // python: __import__('datetime').datetime.fromisoformat('20240301T150405').isoformat() == '2024-03-01T15:04:05'
    assert (fromisoformat('20240301T150405') or { panic(err.msg()) }).isoformat() == '2024-03-01T15:04:05'
    // python: __import__('datetime').datetime.fromisoformat('2024-03-01T15:04:05,123').isoformat() == '2024-03-01T15:04:05.123000'
    assert (fromisoformat('2024-03-01T15:04:05,123') or { panic(err.msg()) }).isoformat() == '2024-03-01T15:04:05.123000'
}

fn test_timedelta_math_and_zones() {
    td := timedelta(days: -1, seconds: 1) or { panic(err.msg()) }
    // python: str(__import__('datetime').timedelta(days=-1, seconds=1)) == '-1 day, 0:00:01'
    assert td.str() == '-1 day, 0:00:01'
    // python: __import__('datetime').timedelta(days=-1, seconds=1).total_seconds() == -86399.0
    assert td.total_seconds() == -86399.0
    // python: __import__('datetime').timedelta(days=-1, seconds=1).days == -1
    assert td.days() == -1
    // python: __import__('datetime').timedelta(days=-1, seconds=1).seconds == 1
    assert td.seconds() == 1
    // python: __import__('datetime').timedelta(microseconds=-1).microseconds == 999999
    assert (timedelta(microseconds: -1) or { panic(err.msg()) }).microseconds() == 999999
    // python: (__import__('datetime').timedelta(minutes=2) + __import__('datetime').timedelta(seconds=30)).total_seconds() == 150
    a := timedelta(minutes: 2) or { panic(err.msg()) }
    b := timedelta(seconds: 30) or { panic(err.msg()) }
    assert (a.add(b) or { panic(err.msg()) }).total_seconds() == 150.0
    // python: (__import__('datetime').timedelta(minutes=2) - __import__('datetime').timedelta(seconds=30)).total_seconds() == 90
    assert (a.subtract(b) or { panic(err.msg()) }).total_seconds() == 90.0
    // python: (-__import__('datetime').timedelta(minutes=2)).total_seconds() == -120
    assert (a.neg() or { panic(err.msg()) }).total_seconds() == -120.0
    offset := timedelta(hours: -5, minutes: -30) or { panic(err.msg()) }
    zone := timezone(offset, '') or { panic(err.msg()) }
    // python: str(__import__('datetime').timezone(__import__('datetime').timedelta(hours=-5,minutes=-30))) == 'UTC-05:30'
    assert zone.str() == 'UTC-05:30'
    // python: __import__('datetime').timezone(__import__('datetime').timedelta(hours=-5,minutes=-30)).utcoffset(None).total_seconds() == -19800
    assert zone.utcoffset().total_seconds() == -19800.0
    // python: str(__import__('datetime').timezone.utc) == 'UTC'
    assert utc.tzname() == 'UTC'
    // python: __import__('datetime').timezone(__import__('datetime').timedelta(microseconds=1)).utcoffset(None).total_seconds() == 0.000001
    micro_offset := timezone(timedelta(microseconds: 1) or { panic(err.msg()) }, '') or { panic(err.msg()) }
    assert micro_offset.utcoffset().total_seconds() == 0.000001
    // python: __import__('datetime').datetime(2024, 1, 1, tzinfo=__import__('datetime').timezone(__import__('datetime').timedelta(microseconds=1))).isoformat() == '2024-01-01T00:00:00+00:00:00.000001'
    with_micro := new_datetime(2024, 1, 1, tzinfo: micro_offset) or { panic(err.msg()) }
    assert with_micro.isoformat() == '2024-01-01T00:00:00+00:00:00.000001'
    // python: __import__('datetime').datetime.fromisoformat('2024-01-01T00:00:00+00:00:01.000001').isoformat() == '2024-01-01T00:00:00+00:00:01.000001'
    assert (fromisoformat('2024-01-01T00:00:00+00:00:01.000001') or { panic(err.msg()) }).isoformat() == '2024-01-01T00:00:00+00:00:01.000001' 
}

fn test_datetime_arithmetic() {
    a := fromisoformat('2024-01-01T01:00:00+01:00') or { panic(err.msg()) }
    b := fromisoformat('2023-12-31T19:00:00-05:00') or { panic(err.msg()) }
    // python: (__import__('datetime').datetime.fromisoformat('2024-01-01T01:00:00+01:00')-__import__('datetime').datetime.fromisoformat('2023-12-31T19:00:00-05:00')).total_seconds() == 0
    assert (a.subtract(b) or { panic(err.msg()) }).total_seconds() == 0.0
    // python: __import__('datetime').datetime.fromisoformat('2024-01-01T01:00:00+01:00') == __import__('datetime').datetime.fromisoformat('2023-12-31T19:00:00-05:00')
    assert (a.compare(b) or { panic(err.msg()) }) == 0
    // python: __import__('datetime').datetime.fromisoformat('2024-01-01T01:00:00+01:00').timestamp() == 1704067200.0
    assert (a.timestamp() or { panic(err.msg()) }) == 1704067200.0
    // python: (__import__('datetime').datetime(2024, 1, 1) + __import__('datetime').timedelta(days=31)).isoformat() == '2024-02-01T00:00:00'
    naive := new_datetime(2024, 1, 1) or { panic(err.msg()) }
    delta := timedelta(days: 31) or { panic(err.msg()) }
    assert (naive.add(delta) or { panic(err.msg()) }).isoformat() == '2024-02-01T00:00:00'
    // python: (__import__('datetime').datetime(2024, 2, 29) - __import__('datetime').datetime(2024, 1, 1)).days == 59
    feb := new_datetime(2024, 2, 29) or { panic(err.msg()) }
    assert (feb.subtract(naive) or { panic(err.msg()) }).days() == 59
    // python: __import__('datetime').datetime.fromtimestamp(0, __import__('datetime').timezone.utc).isoformat() == '1970-01-01T00:00:00+00:00'
    assert (fromtimestamp(0.0, tzinfo: utc) or { panic(err.msg()) }).isoformat() == '1970-01-01T00:00:00+00:00'
    // python: __import__('datetime').datetime.fromtimestamp(-0.000001, __import__('datetime').timezone.utc).isoformat() == '1969-12-31T23:59:59.999999+00:00'
    assert (fromtimestamp(-0.000001, tzinfo: utc) or { panic(err.msg()) }).isoformat() == '1969-12-31T23:59:59.999999+00:00'
    // python: __import__('datetime').datetime.fromisoformat('2024-01-01T01:00:00+01:00').astimezone(__import__('datetime').timezone.utc).isoformat() == '2024-01-01T00:00:00+00:00'
    assert (a.astimezone(utc) or { panic(err.msg()) }).isoformat() == '2024-01-01T00:00:00+00:00'
    // python: __import__('datetime').datetime.fromisoformat('2024-01-01T01:00:00+01:00').tzname() == 'UTC+01:00'
    assert (a.tzname() or { '' }) == 'UTC+01:00'
    // python: __import__('datetime').datetime.fromisoformat('2024-01-01T01:00:00+01:00').utcoffset().total_seconds() == 3600
    assert (a.utcoffset() or { Timedelta{} }).total_seconds() == 3600.0
}

fn test_strptime_and_errors() {
    // python: __import__('datetime').datetime.strptime('04/05/2024 08:07:06.12','%m/%d/%Y %H:%M:%S.%f').isoformat() == '2024-04-05T08:07:06.120000'
    assert (strptime('04/05/2024 08:07:06.12', '%m/%d/%Y %H:%M:%S.%f') or { panic(err.msg()) }).isoformat() == '2024-04-05T08:07:06.120000'
    // python: __import__('datetime').datetime.strptime('Dec 31, 23 at 11:59 PM', '%b %d, %y at %I:%M %p').isoformat() == '2023-12-31T23:59:00'
    assert (strptime('Dec 31, 23 at 11:59 PM', '%b %d, %y at %I:%M %p') or { panic(err.msg()) }).isoformat() == '2023-12-31T23:59:00'
    // python: __import__('datetime').datetime.strptime('2024 060','%Y %j').isoformat() == '2024-02-29T00:00:00'
    assert (strptime('2024 060', '%Y %j') or { panic(err.msg()) }).isoformat() == '2024-02-29T00:00:00'
    // python: __import__('datetime').datetime.strptime('2024-01-01+0000', '%Y-%m-%d%z').isoformat() == '2024-01-01T00:00:00+00:00'
    assert (strptime('2024-01-01+0000', '%Y-%m-%d%z') or { panic(err.msg()) }).isoformat() == '2024-01-01T00:00:00+00:00'
    // python: error_text(lambda: __import__('datetime').date(2023, 2, 29)).startswith('ValueError|day is out of range for month')
    _ = new_date(2023, 2, 29) or { assert pyrt.caught(err, 'ValueError') != none; Date{} }
    // python: error_text(lambda: __import__('datetime').datetime.fromisoformat('2024-13-99')).startswith('ValueError|month must be in 1..12')
    _ = fromisoformat('2024-13-99') or { assert pyrt.caught(err, 'ValueError') != none; Datetime{} }
    // python: error_text(lambda: __import__('datetime').datetime.now(__import__('datetime').timezone.utc)-__import__('datetime').datetime.now()).endswith("can't subtract offset-naive and offset-aware datetimes")
    aware := fromisoformat('2024-01-01T00:00:00+00:00') or { panic(err.msg()) }
    naive := fromisoformat('2024-01-01T00:00:00') or { panic(err.msg()) }
    _ = aware.subtract(naive) or { assert err.msg() == "can't subtract offset-naive and offset-aware datetimes"; Timedelta{} }
    // runtime: local now and local fromtimestamp require the host machine's timezone and DST tables.
    now_utc := now(tzinfo: utc) or { panic(err.msg()) }
    assert now_utc.tzinfo != none
    _ = utcnow() or { panic(err.msg()) }
}

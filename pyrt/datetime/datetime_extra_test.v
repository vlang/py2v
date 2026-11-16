module datetime

import pyrt

fn test_datetime_extra() { check_datetime_extra() or { panic(err.msg()) } }
fn check_datetime_extra() ! {
    d := new_datetime(2024, 2, 29, hour: 12, minute: 34, second: 56, microsecond: 7, tzinfo: utc)!
    clock := d.time()
    zoned := d.timetz()
    // python: datetime.datetime(2024,2,29).isoweekday() == 4
    assert d.isoweekday() == 4
    // python: datetime.datetime(2024,2,29).weekday() == 3
    assert d.weekday() == 3
    // python: str(datetime.datetime(2024,2,29,12,34,56,7,tzinfo=datetime.UTC).date()) == '2024-02-29'
    assert d.date().str() == '2024-02-29'
    // python: datetime.datetime(2024,2,29,12,34,56,7,tzinfo=datetime.UTC).time().isoformat() == '12:34:56.000007'
    assert clock.isoformat() == '12:34:56.000007'
    // python: datetime.datetime(2024,2,29,12,34,56,7,tzinfo=datetime.UTC).time().tzinfo is None
    assert clock.tzinfo == none
    // python: str(datetime.datetime(2024,2,29,12,34,56,7,tzinfo=datetime.UTC).timetz()) == '12:34:56.000007+00:00'
    assert zoned.str() == '12:34:56.000007+00:00'
    // python: datetime.time(12,tzinfo=datetime.UTC).tzname() == 'UTC'
    assert (zoned.tzname() or { '' }) == 'UTC'
    // python: datetime.time(12,tzinfo=datetime.UTC).utcoffset().total_seconds() == 0.0
    assert (zoned.utcoffset() or { panic('offset missing') }).total_seconds() == 0.0
    // python: datetime.time().tzname() is None
    assert clock.tzname() == none
    // python: datetime.time().utcoffset() is None
    assert clock.utcoffset() == none
    // python: datetime.time(12,34,56,7).strftime('%H:%M:%S.%f') == '12:34:56.000007'
    assert clock.strftime('%H:%M:%S.%f')! == '12:34:56.000007'
    // python: datetime.datetime(2024,2,29,12,34,56,7,tzinfo=datetime.UTC).replace(year=2020,hour=0,microsecond=0).isoformat() == '2020-02-29T00:34:56+00:00'
    assert d.replace(year: 2020, hour: 0, microsecond: 0)!.isoformat() == '2020-02-29T00:34:56+00:00'
    // python: datetime.datetime(2024,2,29,tzinfo=datetime.UTC).replace(tzinfo=None).tzinfo is None
    assert d.replace(clear_tzinfo: true)!.tzinfo == none
    offset := timezone(timedelta(hours: 2)!, '')!
    changed := d.replace(tzinfo: offset)!
    tomorrow := d.add(timedelta(days: 1)!)!
    earlier := d.subtract_delta(timedelta(seconds: 1)!)!
    // python: datetime.datetime(2024,2,29,12,34,56,7,tzinfo=datetime.UTC).replace(tzinfo=datetime.timezone(datetime.timedelta(hours=2))).isoformat() == '2024-02-29T12:34:56.000007+02:00'
    assert changed.isoformat() == '2024-02-29T12:34:56.000007+02:00'
    // python: (datetime.datetime(2024,2,29,12,34,56,7,tzinfo=datetime.UTC)-datetime.timedelta(seconds=1)).isoformat() == '2024-02-29T12:34:55.000007+00:00'
    assert earlier.isoformat() == '2024-02-29T12:34:55.000007+00:00'
    // python: datetime.datetime(2024,2,29) < datetime.datetime(2024,3,1)
    assert d.lt(tomorrow)!
    // python: datetime.datetime(2024,2,29) <= datetime.datetime(2024,2,29)
    assert d.le(d)!
    // python: datetime.datetime(2024,3,1) > datetime.datetime(2024,2,29)
    assert tomorrow.gt(d)!
    // python: datetime.datetime(2024,3,1) >= datetime.datetime(2024,2,29)
    assert tomorrow.ge(d)!
    // python: datetime.datetime(2024,2,29,tzinfo=datetime.UTC) != datetime.datetime(2024,2,29)
    assert !d.eq(d.replace(clear_tzinfo: true)!)
    // python: bool(datetime.datetime(1,1,1))
    assert d.bool_()
}
fn test_dates_and_times_operators() { check_dates_and_times_operators() or { panic(err.msg()) } }
fn check_dates_and_times_operators() ! {
    d := new_date(2024, 2, 29)!
    following := new_date(2024, 3, 1)!
    negative_second := timedelta(seconds: -1)!
    // python: str(datetime.date(2024,2,29).replace(day=28)) == '2024-02-28'
    assert d.replace(day: 28)!.str() == '2024-02-28'
    // python: str(datetime.date(2024,2,29)+datetime.timedelta(seconds=-1)) == '2024-02-28'
    assert d.add(negative_second)!.str() == '2024-02-28'
    // python: str(datetime.date(2024,2,29)-datetime.timedelta(seconds=-1)) == '2024-03-01'
    assert d.subtract_delta(negative_second)!.str() == '2024-03-01'
    // python: (datetime.date(2024,3,1)-datetime.date(2024,2,29)).days == 1
    assert following.subtract(d)!.days() == 1
    // python: datetime.date(2024,2,29)==datetime.date(2024,2,29)
    assert d.eq(d)
    // python: datetime.date(2024,2,29)<datetime.date(2024,3,1)
    assert d.lt(following)
    // python: datetime.date(2024,2,29)<=datetime.date(2024,2,29)
    assert d.le(d)
    // python: datetime.date(2024,3,1)>datetime.date(2024,2,29)
    assert following.gt(d)
    // python: datetime.date(2024,3,1)>=datetime.date(2024,2,29)
    assert following.ge(d)
    // python: bool(datetime.date(1,1,1))
    assert d.bool_()
    zero := new_time(TimeOptions{})!
    noon := new_time(hour: 12)!
    utc_noon := new_time(hour: 12, tzinfo: utc)!
    offset := timezone(timedelta(hours: 1)!, '')!
    shifted := new_time(hour: 13, tzinfo: offset)!
    // python: str(datetime.time()) == '00:00:00'
    assert zero.str() == '00:00:00'
    // python: datetime.time(12) == datetime.time(12)
    assert noon.eq(noon)
    // python: datetime.time(12) != datetime.time(12,tzinfo=datetime.UTC)
    assert !noon.eq(utc_noon)
    // python: datetime.time(12,tzinfo=datetime.UTC)==datetime.time(13,tzinfo=datetime.timezone(datetime.timedelta(hours=1)))
    assert utc_noon.eq(shifted)
    // python: datetime.time(0)<datetime.time(12)
    assert zero.lt(noon)!
    // python: datetime.time(12)<=datetime.time(12)
    assert noon.le(noon)!
    // python: datetime.time(12)>datetime.time(0)
    assert noon.gt(zero)!
    // python: datetime.time(12)>=datetime.time(12)
    assert noon.ge(noon)!
    // python: bool(datetime.time(0))
    assert zero.bool_()
    // python: datetime.UTC == datetime.timezone(datetime.timedelta(0),'other')
    assert utc.eq(timezone(timedelta(TimedeltaOptions{})!, 'other')!)
}
fn test_timedelta_operator_routes() { check_timedelta_operator_routes() or { panic(err.msg()) } }
fn check_timedelta_operator_routes() ! {
    zero := timedelta(TimedeltaOptions{})!
    a := timedelta(seconds: 3)!
    b := timedelta(seconds: 2)!
    negative := timedelta(days: -1, seconds: 1)!
    // python: str(datetime.timedelta(days=-1,seconds=1)) == '-1 day, 0:00:01'
    assert negative.str() == '-1 day, 0:00:01'
    // python: datetime.timedelta(seconds=3)==datetime.timedelta(seconds=3)
    assert a.eq(a)
    // python: datetime.timedelta(seconds=2)<datetime.timedelta(seconds=3)
    assert b.lt(a)
    // python: datetime.timedelta(seconds=2)<=datetime.timedelta(seconds=2)
    assert b.le(b)
    // python: datetime.timedelta(seconds=3)>datetime.timedelta(seconds=2)
    assert a.gt(b)
    // python: datetime.timedelta(seconds=3)>=datetime.timedelta(seconds=3)
    assert a.ge(a)
    // python: not bool(datetime.timedelta())
    assert !zero.bool_()
    // python: bool(datetime.timedelta(seconds=3))
    assert a.bool_()
    // python: datetime.timedelta(seconds=3)/datetime.timedelta(seconds=2) == 1.5
    assert a.divide(b)! == 1.5
    // python: (datetime.timedelta(seconds=3)*-2).total_seconds() == -6.0
    assert a.multiply(-2)!.total_seconds() == -6.0
    // python: datetime.timedelta(microseconds=-1).days == -1
    assert timedelta(microseconds: -1)!.days() == -1
    // python: datetime.timedelta(microseconds=-1).seconds == 86399
    assert timedelta(microseconds: -1)!.seconds() == 86399
    // python: datetime.timedelta(microseconds=-1).microseconds == 999999
    assert timedelta(microseconds: -1)!.microseconds() == 999999
}
fn datetime_extra_errors(which int) string {
    if which == 0 { new_time(hour: 24) or { return err.msg() } }
    if which == 1 {
        d := new_datetime(2024, 2, 29) or { panic(err.msg()) }
        d.replace(year: 2023) or { return err.msg() }
    }
    if which == 2 {
        a := new_time(hour: 12) or { panic(err.msg()) }
        b := new_time(hour: 12, tzinfo: utc) or { panic(err.msg()) }
        a.lt(b) or { return err.msg() }
    }
    if which == 3 {
        a := timedelta(seconds: 1) or { panic(err.msg()) }
        b := timedelta(TimedeltaOptions{}) or { panic(err.msg()) }
        a.divide(b) or { return err.msg() }
    }
    return '<no error>'
}
fn test_datetime_extra_errors() {
    // python: error_text(lambda: datetime.time(24)) == 'ValueError|hour must be in 0..23'
    assert datetime_extra_errors(0) == 'hour must be in 0..23'
    // python: error_text(lambda: datetime.datetime(2024,2,29).replace(year=2023)) == 'ValueError|day is out of range for month'
    assert datetime_extra_errors(1) == 'day is out of range for month'
    // python: error_text(lambda: datetime.time(12)<datetime.time(12,tzinfo=datetime.UTC)) == "TypeError|can't compare offset-naive and offset-aware times"
    assert datetime_extra_errors(2) == 'can\'t compare offset-naive and offset-aware times'
    // python: error_text(lambda: datetime.timedelta(seconds=1)/datetime.timedelta()) == 'ZeroDivisionError|division by zero'
    assert datetime_extra_errors(3) == 'division by zero'
}

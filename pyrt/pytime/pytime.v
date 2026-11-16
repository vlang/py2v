module pytime

import time
import pyrt

pub fn time_() f64 {
    return f64(time.now().unix_micro()) / 1000000.0
}

pub fn sleep(seconds f64) ! {
    if seconds < 0.0 { return pyrt.raise('ValueError', 'sleep length must be non-negative') }
    if seconds != seconds || seconds > 9223372036.0 {
        return pyrt.raise('OverflowError', 'sleep length out of range')
    }
    time.sleep(time.second.times(seconds))
}

// sys_mono_now is the supplied monotonic nanosecond clock. The reference
// exposes no distinct performance-counter clock; perf_counter aliases it.
pub fn monotonic() f64 {
    return f64(time.sys_mono_now()) / 1000000000.0
}

pub fn perf_counter() f64 {
    return f64(time.sys_mono_now()) / 1000000000.0
}

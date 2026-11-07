// timer.v is used to record durations of actions.

module vsql

import time

// Timer uses the monotonic clock, which is much cheaper to read than the time of
// day (time.now() and subtracting two time.Time both look up the local time
// zone).
pub struct Timer {
	started_at u64
}

pub fn start_timer() Timer {
	return Timer{
		started_at: time.sys_mono_now()
	}
}

pub fn (t Timer) elapsed() time.Duration {
	return time.Duration(i64(time.sys_mono_now() - t.started_at))
}

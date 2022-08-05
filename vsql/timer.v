// timer.v is used to record durations of actions.

module vsql

import time

pub struct Timer {
	started_at time.Time
}

pub fn start_timer() Timer {
	return Timer{
		started_at: time.now()
	}
}

pub fn (t Timer) elapsed() time.Duration {
	return time.now() - t.started_at
}

module providers

import lib.gtk
import time
import vars

struct TimeState {
	store  &vars.VarStore
	gen    &vars.Generation
	my_gen int
}

fn tick_time(data voidptr) int {
	state := unsafe { &TimeState(data) }
	if state.gen.value != state.my_gen {
		return 0
	}
	now := time.now()
	time_str := '${now.hour:02}:${now.minute:02}:${now.second:02}'
	date_str := '${now.year}-${now.month:02}-${now.day:02}'
	unsafe {
		mut store := state.store
		store.set('time', time_str)
		store.set('date', date_str)
	}
	return 1
}

pub fn start_time(store &vars.VarStore, gen &vars.Generation) {
	state := &TimeState{
		store:  store
		gen:    gen
		my_gen: gen.value
	}
	unsafe {
		mut s := store
		s.pin(voidptr(state))
	}
	tick_time(voidptr(state))
	C.g_timeout_add(1000, voidptr(tick_time), state)
}

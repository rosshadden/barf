module providers

import lib.gtk
import os
import time as time_mod
import vars

struct PollUpdate {
	name  string
	value string
	store &vars.VarStore
}

fn poll_apply(data voidptr) int {
	update := unsafe { &PollUpdate(data) }
	unsafe {
		mut store := update.store
		store.set(update.name, update.value)
	}
	return 0
}

fn run_poll(name string, command string, interval int, store &vars.VarStore) {
	for {
		result := os.execute(command)
		value := if result.exit_code == 0 {
			result.output.trim_space()
		} else {
			''
		}
		update := &PollUpdate{
			name:  name
			value: value
			store: store
		}
		C.g_idle_add(voidptr(poll_apply), voidptr(update))
		time_mod.sleep(time_mod.Duration(interval) * time_mod.second)
	}
}

pub fn start_poll(name string, command string, interval int, store &vars.VarStore) {
	spawn run_poll(name, command, interval, store)
}

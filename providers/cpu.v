module providers

import lib.gtk
import os
import vars

struct CpuState {
mut:
	prev_idle  u64
	prev_total u64
	store      &vars.VarStore
}

fn read_cpu_stat() (u64, u64) {
	lines := os.read_lines('/proc/stat') or { return 0, 0 }
	for line in lines {
		if line.starts_with('cpu ') {
			parts := line.fields()
			if parts.len >= 5 {
				user := parts[1].u64()
				nice := parts[2].u64()
				system := parts[3].u64()
				idle := parts[4].u64()
				iowait := if parts.len > 5 { parts[5].u64() } else { u64(0) }
				total := user + nice + system + idle + iowait
				return idle + iowait, total
			}
		}
	}
	return 0, 0
}

fn tick_cpu(data voidptr) int {
	mut state := unsafe { &CpuState(data) }
	idle, total := read_cpu_stat()
	diff_idle := idle - state.prev_idle
	diff_total := total - state.prev_total
	mut pct := u64(0)
	if diff_total > 0 {
		pct = 100 - (diff_idle * 100 / diff_total)
	}
	state.prev_idle = idle
	state.prev_total = total
	unsafe {
		mut store := state.store
		store.set('cpu.avg', pct.str())
	}
	return 1
}

pub fn start_cpu(store &vars.VarStore, interval int) {
	mut state := &CpuState{
		store: store
	}
	unsafe {
		mut s := store
		s.pin(voidptr(state))
	}
	tick_cpu(voidptr(state))
	C.g_timeout_add(u32(interval) * 1000, voidptr(tick_cpu), state)
}

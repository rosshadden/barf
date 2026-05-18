module providers

import lib.gtk
import os
import vars

struct RamState {
	store &vars.VarStore
}

fn read_meminfo() (u64, u64) {
	lines := os.read_lines('/proc/meminfo') or { return 0, 0 }
	mut total := u64(0)
	mut available := u64(0)
	for line in lines {
		if line.starts_with('MemTotal:') {
			total = line.all_after(':').trim_space().all_before(' ').u64()
		} else if line.starts_with('MemAvailable:') {
			available = line.all_after(':').trim_space().all_before(' ').u64()
		}
		if total > 0 && available > 0 {
			break
		}
	}
	return total, available
}

fn tick_ram(data voidptr) int {
	state := unsafe { &RamState(data) }
	total, available := read_meminfo()
	if total > 0 {
		used_mb := (total - available) / 1024
		total_mb := total / 1024
		pct := (used_mb * 100) / total_mb
		unsafe {
			mut store := state.store
			store.set('ram.pct', pct.str())
			store.set('ram.used', used_mb.str())
			store.set('ram.total', total_mb.str())
		}
	}
	return 1
}

pub fn start_ram(store &vars.VarStore, interval int) {
	state := &RamState{
		store: store
	}
	unsafe {
		mut s := store
		s.pin(voidptr(state))
	}
	tick_ram(voidptr(state))
	C.g_timeout_add(u32(interval) * 1000, voidptr(tick_ram), state)
}

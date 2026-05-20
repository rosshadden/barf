module providers

import cmd
import lib.gtk
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

fn run_poll(name string, command cmd.Command, interval int, shell []string, store &vars.VarStore, gen &vars.Generation, my_gen int, lua_rt voidptr) {
	for {
		if gen.value != my_gen {
			return
		}
		if value := cmd.exec(command, shell, lua_rt) {
			update := &PollUpdate{
				name:  name
				value: value
				store: store
			}
			C.g_idle_add(voidptr(poll_apply), voidptr(update))
		}
		time_mod.sleep(time_mod.Duration(interval) * time_mod.second)
	}
}

pub fn start_poll(name string, command cmd.Command, interval int, shell []string, store &vars.VarStore, gen &vars.Generation, lua_rt voidptr) {
	spawn run_poll(name, command, interval, shell, store, gen, gen.value, lua_rt)
}

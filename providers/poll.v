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

fn run_command(shell []string, command string) os.Result {
	mut p := os.new_process(shell[0])
	mut args := []string{}
	for a in shell[1..] {
		args << a
	}
	args << command
	p.set_args(args)
	p.set_redirect_stdio()
	p.wait()
	output := p.stdout_slurp()
	code := p.code
	p.close()
	return os.Result{
		exit_code: code
		output:    output
	}
}

fn run_poll(name string, command string, interval int, shell []string, store &vars.VarStore) {
	env := os.environ()
	for {
		result := run_command(shell, command)
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

pub fn start_poll(name string, command string, interval int, shell []string, store &vars.VarStore) {
	spawn run_poll(name, command, interval, shell, store)
}

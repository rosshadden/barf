module providers

import cmd
import lib.gtk
import os
import time as time_mod
import vars

struct ListenUpdate {
	name  string
	value string
	store &vars.VarStore
}

fn listen_apply(data voidptr) int {
	update := unsafe { &ListenUpdate(data) }
	unsafe {
		mut store := update.store
		store.set(update.name, update.value)
	}
	return 0
}

fn run_listen(name string, listen_cmd string, shell []string, override cmd.Command, store &vars.VarStore, gen &vars.Generation, my_gen int, lua_rt voidptr) {
	mut p := os.new_process(shell[0])
	mut args := []string{}
	for a in shell[1..] {
		args << a
	}
	args << listen_cmd
	p.set_args(args)
	p.set_redirect_stdio()
	p.run()

	mut partial := ''
	for {
		if gen.value != my_gen {
			if p.is_alive() {
				p.signal_kill()
				p.wait()
			}
			p.close()
			return
		}
		if chunk := p.pipe_read(.stdout) {
			partial += chunk
			for {
				idx := partial.index_u8(`\n`)
				if idx < 0 {
					break
				}
				line := partial[..idx].trim_space()
				partial = partial[idx + 1..]
				if override.is_set() {
					if value := cmd.exec(override, shell, lua_rt, [line]) {
						update := &ListenUpdate{
							name:  name
							value: value
							store: store
						}
						C.g_idle_add(voidptr(listen_apply), voidptr(update))
					}
				} else {
					update := &ListenUpdate{
						name:  name
						value: line
						store: store
					}
					C.g_idle_add(voidptr(listen_apply), voidptr(update))
				}
			}
		} else if !p.is_alive() {
			break
		} else {
			time_mod.sleep(50 * time_mod.millisecond)
		}
	}
	p.close()
}

pub fn start_listen(name string, listen_cmd string, shell []string, override cmd.Command, store &vars.VarStore, gen &vars.Generation, lua_rt voidptr) {
	spawn run_listen(name, listen_cmd, shell, override, store, gen, gen.value, lua_rt)
}

module ipc

import os
import vars

pub type VarUpdateFn = fn (string, string, voidptr)

pub fn sock_path() string {
	runtime := os.getenv('XDG_RUNTIME_DIR')
	if runtime != '' {
		return os.join_path(runtime, 'barf.sock')
	}
	return '/tmp/barf.sock'
}

fn make_addr(path string) C.sockaddr_un {
	mut addr := C.sockaddr_un{}
	C.memset(&addr, 0, sizeof(addr))
	addr.sun_family = u16(af_unix)
	C.strncpy(&addr.sun_path[0], path.str, usize(sun_path_len - 1))
	return addr
}

fn read_line(fd int) string {
	mut buf := [1]u8{}
	mut line := ''
	for {
		n := C.read(fd, &buf[0], 1)
		if n <= 0 {
			break
		}
		ch := buf[0]
		if ch == `\n` {
			break
		}
		line += ch.ascii_str()
	}
	return line
}

fn handle_conn(fd int, store &vars.VarStore, update_fn VarUpdateFn, update_data voidptr) {
	line := read_line(fd).trim_space()
	sp := line.index(' ') or { -1 }
	cmd_name := if sp >= 0 { line[..sp] } else { line }
	rest := if sp >= 0 { line[sp + 1..] } else { '' }
	match cmd_name {
		'update' {
			eq_idx := rest.index('=') or { -1 }
			if eq_idx < 0 {
				return
			}
			name := rest[..eq_idx]
			value := rest[eq_idx + 1..]
			update_fn(name, value, update_data)
			msg := 'ok\n'
			C.write(fd, msg.str, usize(msg.len))
		}
		'get' {
			if rest == '' {
				return
			}
			value := store.get(rest)
			msg := '${value}\n'
			C.write(fd, msg.str, usize(msg.len))
		}
		'state' {
			out := store.to_json()
			C.write(fd, out.str, usize(out.len))
		}
		else {}
	}
}

pub fn serve(store &vars.VarStore, update_fn VarUpdateFn, update_data voidptr) {
	path := sock_path()
	C.unlink(path.str)
	fd := C.socket(af_unix, sock_stream, 0)
	if fd < 0 {
		eprintln('barf: ipc socket failed')
		return
	}
	addr := make_addr(path)
	if C.bind(fd, &addr, sizeof(addr)) < 0 {
		eprintln('barf: ipc bind failed: ${path}')
		C.close(fd)
		return
	}
	if C.listen(fd, 8) < 0 {
		eprintln('barf: ipc listen failed')
		C.close(fd)
		return
	}
	for {
		conn := C.accept(fd, unsafe { nil }, unsafe { nil })
		if conn < 0 {
			continue
		}
		handle_conn(conn, store, update_fn, update_data)
		C.close(conn)
	}
}

pub fn run_client(args []string) ! {
	path := sock_path()
	fd := C.socket(af_unix, sock_stream, 0)
	if fd < 0 {
		return error('barf: socket() failed')
	}
	addr := make_addr(path)
	if C.connect(fd, &addr, sizeof(addr)) < 0 {
		C.close(fd)
		return error('barf is not running (could not connect to ${path})')
	}
	msg := args.join(' ') + '\n'
	C.write(fd, msg.str, usize(msg.len))
	mut buf := [4096]u8{}
	mut response := ''
	for {
		n := C.read(fd, &buf[0], usize(buf.len))
		if n <= 0 {
			break
		}
		response += unsafe { (&buf[0]).vstring_with_len(int(n)) }
	}
	C.close(fd)
	if response != '' {
		print(response)
	}
}

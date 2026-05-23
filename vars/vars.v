module vars

@[heap]
pub struct Generation {
pub mut:
	value int
}

pub type VarChangeFn = fn (voidptr)

struct Subscriber {
	cb   VarChangeFn = unsafe { nil }
	data voidptr
}

@[heap]
pub struct VarStore {
mut:
	values      map[string]string
	is_json     map[string]bool
	subscribers map[string][]Subscriber
	refs        []voidptr
}

pub fn (mut s VarStore) pin(ptr voidptr) {
	s.refs << ptr
}

pub fn (mut s VarStore) clear() {
	s.subscribers = map[string][]Subscriber{}
	s.refs = []
}

pub fn (mut s VarStore) set(name string, value string) {
	if name in s.values && s.values[name] == value && !s.is_json[name] {
		return
	}
	s.values[name] = value
	s.is_json[name] = false
	for sub in s.subscribers[name] or { [] } {
		sub.cb(sub.data)
	}
}

pub fn (mut s VarStore) set_json(name string, value string) {
	if name in s.values && s.values[name] == value && s.is_json[name] {
		return
	}
	s.values[name] = value
	s.is_json[name] = true
	for sub in s.subscribers[name] or { [] } {
		sub.cb(sub.data)
	}
}

pub fn (s &VarStore) get(name string) string {
	return s.values[name] or { '' }
}

pub fn (mut s VarStore) subscribe(name string, cb VarChangeFn, data voidptr) {
	if name !in s.subscribers {
		s.subscribers[name] = []
	}
	unsafe {
		s.subscribers[name] << Subscriber{
			cb:   cb
			data: data
		}
	}
}

pub fn (s &VarStore) to_json() string {
	mut out := '{'
	mut first := true
	for k, v in s.values {
		if !first {
			out += ','
		}
		first = false
		out += json_quote(k)
		out += ':'
		if s.is_json[k] {
			out += v
		} else {
			out += json_quote(v)
		}
	}
	out += '}'
	return out
}

fn json_quote(s string) string {
	hex_chars := '0123456789abcdef'
	mut out := '"'
	for i := 0; i < s.len; i++ {
		c := s[i]
		if c == `"` {
			out += '\\"'
		} else if c == `\\` {
			out += '\\\\'
		} else if c == `\n` {
			out += '\\n'
		} else if c == `\r` {
			out += '\\r'
		} else if c == `\t` {
			out += '\\t'
		} else if c < 0x20 {
			out += '\\u00'
			out += hex_chars[(c >> 4) & 0xF].ascii_str()
			out += hex_chars[c & 0xF].ascii_str()
		} else {
			out += c.ascii_str()
		}
	}
	out += '"'
	return out
}

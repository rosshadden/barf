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
	if name in s.values && s.values[name] == value {
		return
	}
	s.values[name] = value
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

pub fn (mut s VarStore) to_json() string {
	mut out := '{'
	for k, v in s.values {
		out += '"${k}":"${v}",'
	}
	if out.len > 1 {
		out = out[..out.len - 1]
	}
	out += '}'
	return out
}

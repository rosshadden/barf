module vars

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

pub enum SegKind {
	literal
	variable
}

pub struct Segment {
pub:
	kind  SegKind
	value string
}

pub struct Template {
pub:
	segments []Segment
}

fn find_var_start(s string) int {
	for i := 0; i < s.len - 1; i++ {
		if s[i] == `$` && s[i + 1] == `{` {
			return i
		}
	}
	return -1
}

pub fn parse_template(text string) Template {
	mut segs := []Segment{}
	mut rest := text
	for rest.len > 0 {
		idx := find_var_start(rest)
		if idx < 0 {
			segs << Segment{
				kind:  .literal
				value: rest
			}
			break
		}
		if idx > 0 {
			segs << Segment{
				kind:  .literal
				value: rest[..idx]
			}
		}
		rest = rest[idx + 2..]
		end := rest.index_u8(`}`)
		if end < 0 {
			segs << Segment{
				kind:  .literal
				value: rest
			}
			break
		}
		segs << Segment{
			kind:  .variable
			value: rest[..end]
		}
		rest = rest[end + 1..]
	}
	return Template{
		segments: segs
	}
}

pub fn (t &Template) render(store &VarStore) string {
	mut parts := []string{cap: t.segments.len}
	for seg in t.segments {
		if seg.kind == .literal {
			parts << seg.value
		} else {
			parts << store.get(seg.value)
		}
	}
	return parts.join('')
}

pub fn (t &Template) var_names() []string {
	mut names := []string{}
	for seg in t.segments {
		if seg.kind == .variable {
			names << seg.value
		}
	}
	return names
}

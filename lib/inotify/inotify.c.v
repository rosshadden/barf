module inotify

#include <sys/inotify.h>
#include <sys/select.h>
#include <unistd.h>

pub const in_close_write = u32(0x0008)
pub const in_moved_to = u32(0x0080)
pub const in_create = u32(0x0100)
pub const in_cloexec = int(0x80000)

pub fn C.inotify_init1(flags int) int
pub fn C.inotify_add_watch(fd int, pathname &char, mask u32) int

@[typedef]
pub struct C.fd_set {}

@[typedef]
pub struct C.timeval {
pub mut:
	tv_sec  i64
	tv_usec i64
}

pub fn C.select(nfds int, readfds &C.fd_set, writefds &C.fd_set, exceptfds &C.fd_set, timeout &C.timeval) int
pub fn C.FD_ZERO(set &C.fd_set)
pub fn C.FD_SET(fd int, set &C.fd_set)
pub fn C.FD_ISSET(fd int, set &C.fd_set) int
pub fn C.read(fd int, buf voidptr, count usize) isize
pub fn C.close(fd int) int

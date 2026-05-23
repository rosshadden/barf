module ipc

#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

pub const af_unix = int(1)
pub const sock_stream = int(1)
pub const sol_socket = int(1)
pub const so_reuseaddr = int(2)
pub const sun_path_len = int(108)

pub struct C.sockaddr_un {
pub mut:
	sun_family u16
	sun_path   [108]char
}

pub fn C.socket(domain int, typ int, protocol int) int
pub fn C.bind(sockfd int, addr &C.sockaddr_un, addrlen u32) int
pub fn C.listen(sockfd int, backlog int) int
pub fn C.accept(sockfd int, addr &C.sockaddr_un, addrlen &u32) int
pub fn C.connect(sockfd int, addr &C.sockaddr_un, addrlen u32) int
pub fn C.read(fd int, buf voidptr, count usize) isize
pub fn C.write(fd int, buf voidptr, count usize) isize
pub fn C.close(fd int) int
pub fn C.unlink(path &char) int
pub fn C.strlen(s &char) usize
pub fn C.strnlen(s &char, maxlen usize) usize
pub fn C.memset(s voidptr, c int, n usize) voidptr
pub fn C.strncpy(dest &char, src &char, n usize) &char

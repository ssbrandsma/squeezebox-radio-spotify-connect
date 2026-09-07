/* PoC only: old Linux fallbacks. CLOEXEC fallback has a fork/exec race;
 * do not use this as a production compatibility layer without auditing. */
#include <errno.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <sys/epoll.h>
#include <sys/eventfd.h>
#include <sys/syscall.h>
#include <unistd.h>

static int set_flags(int fd, int flags) {
    if (fd < 0) return fd;
    if (((flags & SOCK_CLOEXEC) && syscall(SYS_fcntl, fd, F_SETFD, FD_CLOEXEC) < 0) ||
        ((flags & SOCK_NONBLOCK) && syscall(SYS_fcntl, fd, F_SETFL, O_NONBLOCK) < 0)) {
        int saved = errno; close(fd); errno = saved; return -1;
    }
    return fd;
}
int __wrap_epoll_create1(int flags) {
    int fd = syscall(SYS_epoll_create1, flags);
    if (fd < 0 && errno == ENOSYS && !(flags & ~EPOLL_CLOEXEC))
        fd = set_flags(syscall(SYS_epoll_create, 1), flags);
    return fd;
}
int __wrap_eventfd(unsigned int count, int flags) {
    int fd = syscall(SYS_eventfd2, count, flags);
    if (fd < 0 && errno == ENOSYS && !(flags & ~(EFD_CLOEXEC|EFD_NONBLOCK)))
        fd = set_flags(syscall(SYS_eventfd, count), flags);
    return fd;
}
int __wrap_socket(int domain, int type, int protocol) {
    int fd = syscall(SYS_socket, domain, type, protocol);
    if (fd < 0 && errno == EINVAL && (type & (SOCK_CLOEXEC|SOCK_NONBLOCK)))
        fd = set_flags(syscall(SYS_socket, domain, type & ~(SOCK_CLOEXEC|SOCK_NONBLOCK), protocol), type);
    return fd;
}
int __wrap_accept4(int fd, struct sockaddr *addr, socklen_t *len, int flags) {
    int result = syscall(SYS_accept4, fd, addr, len, flags);
    if (result < 0 && errno == ENOSYS && !(flags & ~(SOCK_CLOEXEC|SOCK_NONBLOCK)))
        result = set_flags(syscall(SYS_accept, fd, addr, len), flags);
    return result;
}

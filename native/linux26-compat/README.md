# Linux 2.6 compatibility shim

The final ARM bridge and librespot builds must link the reviewed Linux 2.6
syscall shim from the research repository. It is intentionally not copied into
the framework release until the native build is enabled; `build-native.ps1`
expects the shim object at this path and fails closed when it is absent.

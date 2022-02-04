# bash-memory-dump
Linux process memory dumper in BASH

# Usage
<pre>
Usage: memory-dump.sh [options]
       -p PID              Dump memory region of the process which is specified by PID.
       -m MEMORY_REGION    Dump memory region of process (stack, heap, anon, all).
       -d DUMP_METHOD      Dump memory method for dumping (gdb, dd).
       -v                  Show script version.
</pre>

# Version for sh

There is also a version running in `sh` on restricted environments like in embedded systems.

See [memory-dump-sh.sh](memory-dump-sh.sh).

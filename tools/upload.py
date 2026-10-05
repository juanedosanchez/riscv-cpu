#!/usr/bin/env python3
"""Upload a program to the CPU over UART and show its output.

Usage:
  tools/upload.py programs/hello.c          # build, upload, then monitor
  tools/upload.py build/foo.bin             # upload an existing image
  tools/upload.py --monitor                 # only show UART output
  tools/upload.py programs/x.S --no-monitor

After starting, press the S0 button on the board: the bootloader prints
"RVBOOT" after every reset and waits 0.5 s for an upload. Stop the
monitor with Ctrl-C.

The serial port is detected automatically (the Dock's debugger appears as
two /dev/cu.usbserial-* ports; the UART is the second). Override with
--port. Uses only the Python standard library (no pyserial).
"""

import argparse
import glob
import os
import select
import subprocess
import sys
import termios
import time
import tty

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BAUD = termios.B115200


def find_port():
    ports = sorted(glob.glob("/dev/cu.usbserial-*"))
    if not ports:
        sys.exit("upload: no /dev/cu.usbserial-* port found; is the board plugged in?")
    return ports[-1]            # the higher-numbered port is the UART channel


def open_port(path):
    fd = os.open(path, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    attrs = termios.tcgetattr(fd)
    attrs[0] = 0                                        # iflag
    attrs[1] = 0                                        # oflag
    attrs[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
    attrs[3] = 0                                        # lflag
    attrs[4] = BAUD
    attrs[5] = BAUD
    attrs[6][termios.VMIN] = 0
    attrs[6][termios.VTIME] = 0
    termios.tcsetattr(fd, termios.TCSANOW, attrs)
    termios.tcflush(fd, termios.TCIOFLUSH)
    return fd


def read_available(fd, timeout):
    ready, _, _ = select.select([fd], [], [], timeout)
    if ready:
        try:
            return os.read(fd, 4096)
        except BlockingIOError:
            return b""
    return b""


def write_all(fd, data):
    view = memoryview(data)
    while view:
        try:
            written = os.write(fd, view)
            view = view[written:]
        except BlockingIOError:
            select.select([], [fd], [], 1.0)
    termios.tcdrain(fd)


def build(source):
    if source.endswith(".bin"):
        return source
    output = os.path.join(ROOT, "build", "upload")
    subprocess.run([sys.executable, os.path.join(ROOT, "tools", "mkprog.py"),
                    "-o", output, source], check=True)
    return output + ".bin"


def upload(fd, image):
    print("Press S0 on the board to reset it...", flush=True)
    seen = b""
    while b"RVBOOT" not in seen:
        seen = (seen + read_available(fd, 0.1))[-64:]

    checksum = sum(image) & 0xFFFFFFFF
    packet = (b"L" + len(image).to_bytes(4, "little") + image
              + checksum.to_bytes(4, "little"))
    write_all(fd, packet)

    deadline = time.time() + 2.0
    reply = b""
    while time.time() < deadline and not reply:
        reply = read_available(fd, 0.1)
    if reply[:1] == b"K":
        print(f"Uploaded {len(image)} bytes; program running.", flush=True)
        return reply[1:]
    if reply[:1] == b"E":
        sys.exit("upload: board reported a checksum error ('E'); try again")
    sys.exit(f"upload: no acknowledgement from the bootloader (got {reply!r})")


def monitor(fd, initial=b""):
    print("--- UART monitor (Ctrl-C to quit; typed keys are sent) ---", flush=True)
    sys.stdout.buffer.write(initial)
    sys.stdout.flush()

    stdin_fd = sys.stdin.fileno()
    interactive = os.isatty(stdin_fd)
    saved = termios.tcgetattr(stdin_fd) if interactive else None
    try:
        if interactive:
            tty.setcbreak(stdin_fd)
        while True:
            sources = [fd, stdin_fd] if interactive else [fd]
            ready, _, _ = select.select(sources, [], [], 0.5)
            if fd in ready:
                data = read_available(fd, 0)
                sys.stdout.buffer.write(data)
                sys.stdout.flush()
            if interactive and stdin_fd in ready:
                key = os.read(stdin_fd, 64).replace(b"\n", b"\r")
                write_all(fd, key)
    except KeyboardInterrupt:
        print()
    finally:
        if saved:
            termios.tcsetattr(stdin_fd, termios.TCSADRAIN, saved)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("program", nargs="?", help=".c/.S source or .bin image")
    parser.add_argument("--port", help="serial port (default: auto-detect)")
    parser.add_argument("--monitor", action="store_true", help="only monitor, don't upload")
    parser.add_argument("--no-monitor", action="store_true", help="exit after uploading")
    args = parser.parse_args()

    if not args.program and not args.monitor:
        parser.error("give a program to upload, or --monitor")

    image = None
    if args.program:
        with open(build(args.program), "rb") as f:
            image = f.read()
        if len(image) > 16384:
            sys.exit(f"upload: image is {len(image)} bytes, RAM holds 16384")

    port = args.port or find_port()
    print(f"Using {port}", flush=True)
    fd = open_port(port)
    try:
        leftover = upload(fd, image) if image is not None else b""
        if not args.no_monitor:
            monitor(fd, leftover)
    finally:
        os.close(fd)


if __name__ == "__main__":
    main()

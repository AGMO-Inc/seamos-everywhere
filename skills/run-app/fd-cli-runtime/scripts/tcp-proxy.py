#!/usr/bin/env python3
"""TCP proxy: forwards 0.0.0.0:LISTEN_PORT -> 127.0.0.1:TARGET_PORT.

Used to expose localhost-only services (e.g. TestSimulator web UI)
through Docker port mapping.

Usage: tcp-proxy.py [LISTEN_PORT] [TARGET_PORT]
  Default: 16563 -> 6563
"""
import socket
import sys
import threading

LISTEN_PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 16563
TARGET_PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 6563


def forward(src, dst):
    try:
        while True:
            data = src.recv(4096)
            if not data:
                break
            dst.sendall(data)
    except Exception:
        pass
    finally:
        src.close()
        dst.close()


def main():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("0.0.0.0", LISTEN_PORT))
    srv.listen(5)

    while True:
        client, _ = srv.accept()
        try:
            target = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            target.connect(("127.0.0.1", TARGET_PORT))
            threading.Thread(target=forward, args=(client, target), daemon=True).start()
            threading.Thread(target=forward, args=(target, client), daemon=True).start()
        except ConnectionRefusedError:
            client.close()


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Tiny TCP forwarder used by run-via-fd-cli.sh.

TestSimulator's Spark/Jetty UI gateway binds to 127.0.0.1 inside the
fd-cli container. Docker port publishing routes external traffic to the
container's eth0 interface, so a 127.0.0.1-only socket is unreachable
from the host. This forwarder accepts on 0.0.0.0:<listen_port> and
relays each connection to 127.0.0.1:<target_port>, restoring host
reachability without modifying the upstream Spark code.

Usage: ui-forwarder.py <listen_port> <target_host> <target_port>
"""
import os, sys, socket, threading


def pump(src, dst):
    try:
        while True:
            data = src.recv(8192)
            if not data:
                break
            dst.sendall(data)
    except Exception:
        pass
    finally:
        for s in (src, dst):
            try:
                s.shutdown(socket.SHUT_RDWR)
            except Exception:
                pass
            try:
                s.close()
            except Exception:
                pass


def serve(listen_port, target_host, target_port):
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("0.0.0.0", listen_port))
    srv.listen(128)
    sys.stderr.write(
        f"[ui-forwarder] 0.0.0.0:{listen_port} -> {target_host}:{target_port}\n"
    )
    sys.stderr.flush()
    while True:
        client, _ = srv.accept()
        try:
            backend = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            backend.settimeout(2)
            backend.connect((target_host, target_port))
            backend.settimeout(None)
        except Exception as e:
            sys.stderr.write(f"[ui-forwarder] backend connect failed: {e}\n")
            try:
                client.close()
            except Exception:
                pass
            continue
        threading.Thread(target=pump, args=(client, backend), daemon=True).start()
        threading.Thread(target=pump, args=(backend, client), daemon=True).start()


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.stderr.write("usage: ui-forwarder.py <listen_port> <target_host> <target_port>\n")
        sys.exit(2)
    serve(int(sys.argv[1]), sys.argv[2], int(sys.argv[3]))

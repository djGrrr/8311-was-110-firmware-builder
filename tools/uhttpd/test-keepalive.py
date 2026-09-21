#!/usr/bin/env python3
"""Test UA-independent HTTP keep-alive: test-keepalive.py /path/to/uhttpd.
Uses a temporary document root and loopback only; no modem or browser access.
"""
import http.client
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
from contextlib import contextmanager

SAFARI = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 Version/27.0 Mobile/15E148 Safari/604.1'
CRIOS = 'Mozilla/5.0 (iPhone; CPU iPhone OS 27_0_0 like Mac OS X) AppleWebKit/605.1.15 CriOS/153.0.8010.24 Mobile/15E148 Safari/604.1'
IE = 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)'
AGENTS = [SAFARI, CRIOS, SAFARI.replace('27.0', '5.0'),
          CRIOS.replace('27_0_0', '17_0').replace('153.0.8010.24', '100.0'),
          'Mozilla/5.0 Chrome/153.0 Safari/537.36', IE,
          'UnknownBrowser Version/not-a-version', None]


@contextmanager
def server(root, keepalive):
    with socket.socket() as reservation:
        reservation.bind(('127.0.0.1', 0))
        port = reservation.getsockname()[1]
    process = subprocess.Popen([sys.argv[1], '-f', '-h', root,
                                '-p', f'127.0.0.1:{port}', '-k', str(keepalive)],
                               stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    try:
        for _ in range(50):
            if process.poll() is not None:
                raise RuntimeError(process.stderr.read().decode())
            try:
                with socket.create_connection(('127.0.0.1', port), timeout=0.2):
                    break
            except OSError:
                time.sleep(0.1)
        else:
            raise RuntimeError('uhttpd did not listen')
        yield port
    finally:
        process.terminate()
        process.communicate(timeout=5)


def request(conn, ua, close=False, headers=None, method='GET', status=200):
    h = {} if ua is None else {'User-Agent': ua}
    h.update(headers or {})
    conn.request(method, '/asset.txt', headers=h)
    sock = conn.sock
    response = conn.getresponse()
    body = response.read()
    assert response.status == status, response.status
    assert response.will_close == close, (ua, response.getheader('Connection'))
    if status == 200:
        assert body == b'keepalive-check\n'
    return sock, response


with tempfile.TemporaryDirectory() as root:
    (Path(root) / 'asset.txt').write_text('keepalive-check\n')
    with server(root, 2) as port:
        for ua in AGENTS:
            conn = http.client.HTTPConnection('127.0.0.1', port, timeout=4)
            sock, response = request(conn, ua)
            # POST is deliberately included: old IE must no longer force close.
            assert request(conn, ua, method='POST')[0] is sock
            etag = response.getheader('ETag')
            assert etag
            assert request(conn, ua, headers={'If-None-Match': etag}, status=304)[0] is sock
            request(conn, ua, close=True, headers={'Connection': 'close'})
            conn.close()
            conn = http.client.HTTPConnection('127.0.0.1', port, timeout=4)
            conn._http_vsn, conn._http_vsn_str = 10, 'HTTP/1.0'
            request(conn, ua, close=True)
            conn.close()
        conn = http.client.HTTPConnection('127.0.0.1', port, timeout=4)
        idle, _ = request(conn, CRIOS)
        idle.settimeout(5)
        assert idle.recv(1) == b'', 'Server did not expire idle keep-alive socket'
        conn.close()
        conn = http.client.HTTPConnection('127.0.0.1', port, timeout=4)
        request(conn, CRIOS)
        conn.close()
    with server(root, 0) as port:
        for ua in AGENTS:
            conn = http.client.HTTPConnection('127.0.0.1', port, timeout=4)
            request(conn, ua, close=True)
            conn.close()
print('Passed 8 UA cases: GET/POST reuse, ETag 304, explicit close, HTTP/1.0, keep-alive disabled; idle expiry/reconnect')

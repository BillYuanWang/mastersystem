#!/usr/bin/env python3
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import os
import sys


ROOT = Path(__file__).resolve().parent
CSV_PATH = ROOT / "courses.csv"


class MasterDanceHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_POST(self):
        path = self.path.split("?", 1)[0]
        if path != "/save-csv":
            self.send_error(404, "Not found")
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self.send_error(400, "Bad content length")
            return

        data = self.rfile.read(length)
        CSV_PATH.write_bytes(data)
        self.send_response(204)
        self.end_headers()


def main():
    os.chdir(ROOT)
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    server = ThreadingHTTPServer(("127.0.0.1", port), MasterDanceHandler)
    print(f"Master Dance Reserve: http://127.0.0.1:{port}/index.html")
    server.serve_forever()


if __name__ == "__main__":
    main()

import json
import os
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


def cpu_sample():
    values = [int(x) for x in Path("/proc/stat").read_text().splitlines()[0].split()[1:9]]
    return sum(values), values[3] + values[4]


def metric_values():
    first_total, first_idle = cpu_sample()
    time.sleep(0.3)
    total, idle = cpu_sample()
    cpu = 100 * (1 - (idle - first_idle) / max(1, total - first_total))
    memory = {}
    for line in Path("/proc/meminfo").read_text().splitlines():
        name, value = line.split(":", 1)
        memory[name] = int(value.split()[0])
    disk = os.statvfs("/")
    return {
        "cpu": round(cpu, 1),
        "memory": round(100 * (1 - memory["MemAvailable"] / memory["MemTotal"]), 1),
        "disk": round(100 * (1 - disk.f_bavail / disk.f_blocks), 1),
        "uptime": int(float(Path("/proc/uptime").read_text().split()[0])),
    }


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/metrics":
            self.send_error(404)
            return
        payload = json.dumps(metric_values()).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)


ThreadingHTTPServer(("0.0.0.0", 9100), Handler).serve_forever()

"""Nagios active checks with explicit HTTP status and metric thresholds."""
import http.client
import json
import sys
import time


def emit(state, message):
    labels = ["OK", "WARNING", "CRITICAL", "UNKNOWN"]
    print(labels[state] + " - " + message)
    return state


def check_http(host, port, path, warn, critical):
    conn = http.client.HTTPConnection(host, int(port), timeout=5)
    try:
        start = time.monotonic()
        conn.request("GET", path)
        status = conn.getresponse().status
        elapsed = time.monotonic() - start
        if not 200 <= status < 400:
            return emit(2, f"{host}:{port}{path} returned HTTP {status}")
        state = 2 if elapsed >= float(critical) else int(elapsed >= float(warn))
        return emit(state, f"HTTP {status} in {elapsed:.3f}s")
    finally:
        conn.close()


def check_metric(host, metric, warn, critical):
    conn = http.client.HTTPConnection(host, 9100, timeout=4)
    try:
        conn.request("GET", "/metrics")
        response = conn.getresponse()
        if response.status != 200:
            return emit(2, f"Metrics returned HTTP {response.status}")
        value = float(json.load(response)[metric])
    finally:
        conn.close()
    if metric == "uptime":
        state = 2 if value < float(critical) else int(value < float(warn))
        return emit(state, f"Uptime {value:.0f}s")
    state = 2 if value >= float(critical) else int(value >= float(warn))
    return emit(state, f"{metric} used {value:.1f}% | '{metric}'={value}%;{warn};{critical};0;100")


if __name__ == "__main__":
    try:
        if sys.argv[1] == "http":
            result = check_http(*sys.argv[2:])
        elif sys.argv[1] == "metric":
            result = check_metric(*sys.argv[2:])
        else:
            result = emit(3, "Unknown check type")
    except (OSError, http.client.HTTPException) as error:
        result = emit(2, str(error))
    except (KeyError, ValueError, TypeError, IndexError) as error:
        result = emit(3, str(error))
    raise SystemExit(result)

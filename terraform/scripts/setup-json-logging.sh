#!/bin/bash
# Day 5 — Forward NPMplus nginx access logs to host syslog (facility=local0)
#
# Investigation summary (see handbook.md Day 5 for detail):
#   NPMplus does not log to host syslog directly. With LOGROTATE=true (already
#   set in setup-npmplus.sh's compose.yaml) it writes access logs to
#   /opt/npmplus/nginx/logs/access.log on the HOST filesystem (bind-mounted
#   from /data inside the container). There is no built-in JSON log format or
#   syslog output in NPMplus.
#
#   IMPORTANT (found by real testing, NOT documented anywhere): NPMplus's
#   access.log format is its OWN custom format, not Apache/nginx "combined":
#     [04/Jul/2026:11:26:55 +0000] npmplustest.example.com 1.2.3.4 0.001 "GET /entries HTTP/2.0" 302 116 363 - curl/8.7.1
#     ^time                        ^domain(or ip:port)     ^addr   ^rt   ^request                ^status ^bytes_sent ^req_len ^referer ^user_agent
#   An initial version of this script assumed Apache combined format
#   ("addr - - [time] \"request\" status bytes") and silently produced zero
#   output because the regex never matched. Fixed here with a parser matching
#   NPMplus's real format.
#
# Simplest robust fix that keeps sentinel.tf's AMA -> DCR -> Sentinel pipeline
# unchanged: a small systemd service on the HOST tails access.log, converts
# each line to JSON, and forwards it to syslog local0 via `logger` — exactly
# what the old hand-written nginx json_combined format did, just produced by
# a forwarder instead of nginx itself.
#
# Run this after Day 2 setup-npmplus.sh has already completed and the Proxy
# Host for the app exists (so access.log has content).
#
# Usage:
#   scp -i .learningsteps_key scripts/setup-json-logging.sh azureuser@<vm-ip>:/tmp/
#   ssh -i .learningsteps_key azureuser@<vm-ip> "sudo bash /tmp/setup-json-logging.sh"

set -euo pipefail

FORWARDER=/usr/local/bin/npmplus-log-forwarder.py
ACCESS_LOG=/opt/npmplus/nginx/logs/access.log

echo "==> Writing log forwarder script..."
cat > "$FORWARDER" << 'EOF'
#!/usr/bin/env python3
"""Tails NPMplus's access.log and re-emits each line as JSON to syslog
facility local0 (tag=nginx), matching the shape the Day 5 Sentinel KQL query
expects: {"remote_addr":...,"method":...,"uri":...,"status":...}

NPMplus access.log line format (confirmed by inspection, not documented):
  [04/Jul/2026:11:26:55 +0000] npmplustest.example.com 1.2.3.4 0.001 "GET /entries HTTP/2.0" 302 116 363 - curl/8.7.1
  [time]                       domain                  addr    rt    "request"               status  bytes  req_len referer  user_agent
"""
import json
import re
import subprocess
import sys
import time

ACCESS_LOG = "/opt/npmplus/nginx/logs/access.log"

LINE_RE = re.compile(
    r'^\[(?P<time>[^\]]+)\]\s+'
    r'(?P<domain>\S+)\s+'
    r'(?P<addr>\S+)\s+'
    r'(?P<rt>\S+)\s+'
    r'"(?P<method>\S+)\s+(?P<uri>\S+)\s+\S+"\s+'
    r'(?P<status>\d+)\s+'
    r'(?P<bytes>\d+)'
)

while True:
    try:
        with open(ACCESS_LOG):
            break
    except FileNotFoundError:
        time.sleep(5)

proc = subprocess.Popen(
    ["tail", "-n0", "-F", ACCESS_LOG],
    stdout=subprocess.PIPE, text=True, bufsize=1,
)
for line in proc.stdout:
    m = LINE_RE.match(line.strip())
    if not m:
        continue
    doc = {
        # "seq" (a forwarder-side, sub-microsecond-precision arrival time) is
        # included specifically so repeated identical-looking requests (e.g.
        # a WAF payload sent N times in a row within the same second — exactly
        # the Day 5 "5+ 403s" detection scenario) never produce byte-identical
        # JSON strings. Without this, systemd-journald's message
        # deduplication collapses repeated identical lines into a single
        # "message repeated N times: [...]" entry — confirmed by testing: 6
        # rapid identical attack requests (same second, access log's own
        # timestamp only has 1-second resolution) arrived in Log Analytics as
        # only 2 Syslog rows (1 + "message repeated 5 times"), which silently
        # breaks a naive `summarize count()` in the Sentinel KQL. A
        # microsecond-precision forwarder-side field avoids this deficit
        # entirely rather than requiring the KQL to unpack journald's dedup
        # wrapper text.
        "time": m.group("time"),
        "seq": time.time(),
        "remote_addr": m.group("addr"),
        "domain": m.group("domain"),
        "method": m.group("method"),
        "uri": m.group("uri"),
        "status": int(m.group("status")),
        "bytes_sent": int(m.group("bytes")),
    }
    subprocess.run(["logger", "-p", "local0.info", "-t", "nginx", json.dumps(doc)])
EOF
chmod +x "$FORWARDER"

echo "==> Writing systemd unit..."
cat > /etc/systemd/system/npmplus-log-forwarder.service << EOF
[Unit]
Description=Forward NPMplus access.log to syslog local0 as JSON (for Sentinel)
After=docker.service

[Service]
Type=simple
ExecStart=/usr/bin/python3 ${FORWARDER}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now npmplus-log-forwarder

echo ""
echo "Done. Forwarder is tailing ${ACCESS_LOG} -> syslog local0 (tag=nginx)."
echo ""
echo "Verify locally (generate a request first, then wait ~5s):"
echo "  journalctl -t nginx --since '1 min ago'"
echo ""
echo "Verify in Sentinel (wait 3-10 min for first ingestion):"
echo "  Syslog | where ProcessName == 'nginx' | take 5"

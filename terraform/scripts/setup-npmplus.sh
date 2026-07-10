#!/bin/bash
# Day 2 + Day 3 baseline — Docker, NPMplus (nginx-proxy-manager fork), CrowdSec
#
# Replaces the old hand-rolled nginx + certbot + ModSecurity stack (setup-nginx.sh).
# This script gets the VM to a "baseline" state:
#   - Docker + Compose plugin installed
#   - NPMplus running (admin GUI on :81, HTTP on :80, HTTPS on :443)
#   - CrowdSec running alongside it, collections installed, but NOT yet wired
#     to NPMplus as a bouncer (WAF is "off" until the live Day 2 demo wires it)
#   - oauth2-proxy binary + systemd unit installed but not started (no OIDC
#     creds yet — that's the live Day 3 demo: az ad app create, etc.)
#
# Deliberately NOT done here (left for the live classroom demo):
#   - Creating a Proxy Host in NPMplus for the app
#   - Requesting the Let's Encrypt certificate (SSL toggle)
#   - Registering the CrowdSec bouncer / enabling AppSec on the host
#   - Configuring oauth2-proxy with real Entra ID app credentials
#
# Usage (direct SSH):
#   scp -i .learningsteps_key scripts/setup-npmplus.sh azureuser@<vm-ip>:/tmp/
#   ssh -i .learningsteps_key azureuser@<vm-ip> "sudo bash /tmp/setup-npmplus.sh"
#
# The script is idempotent — safe to run more than once.

set -euo pipefail

NPMPLUS_IMAGE_TAG="2026-06-25-r1"   # pinned release, NOT :develop/:beta — see handbook.md
CROWDSEC_IMAGE_TAG="latest"        # crowdsecurity publishes no equally-pinned "stable" tag scheme at time of writing; documented as a known gap

echo "==> Installing Docker + Compose plugin..."
if ! command -v docker >/dev/null 2>&1; then
    apt-get update -q
    DEBIAN_FRONTEND=noninteractive apt-get install -y -q ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    ARCH=$(dpkg --print-architecture)
    CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
    echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
        > /etc/apt/sources.list.d/docker.list
    apt-get update -q
    DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
systemctl enable --now docker
echo "    docker: $(docker --version)"
echo "    compose: $(docker compose version)"

echo "==> Creating NPMplus + CrowdSec directories..."
mkdir -p /opt/npmplus
mkdir -p /opt/crowdsec/conf/acquis.d
mkdir -p /opt/crowdsec/conf/appsec-configs
mkdir -p /opt/crowdsec/data
mkdir -p /opt/npmplus/crowdsec

# ── FastAPI on localhost only (NPMplus/oauth2-proxy sit in front of it) ───────
echo "==> Binding FastAPI to 127.0.0.1..."
sed -i 's/--host 0\.0\.0\.0/--host 127.0.0.1/' /etc/systemd/system/learningsteps.service
systemctl daemon-reload
systemctl restart learningsteps

# ── compose.yaml ───────────────────────────────────────────────────────────
echo "==> Writing /opt/npmplus/compose.yaml..."
cat > /opt/npmplus/compose.yaml << EOF
name: npmplus
services:
  npmplus:
    container_name: npmplus
    restart: unless-stopped
    image: docker.io/zoeyvid/npmplus:${NPMPLUS_IMAGE_TAG}
    network_mode: host
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
      - SETGID
    security_opt:
      - no-new-privileges:true
    volumes:
      - "/opt/npmplus:/data"
      - "/opt/npmplus/crowdsec:/opt/npmplus/crowdsec"
    environment:
      - "TZ=Etc/UTC"
      - "LOGROTATE=true"
      - "AUTH_REQUEST_OAUTH2PROXY_UPSTREAM=http://127.0.0.1:4180"
      # Fixed (not random) initial admin creds — deliberate choice for the classroom:
      # a random password buried in `docker logs` is fine for one operator, but
      # impractical when the whole class needs to log into the same GUI during a
      # live demo. Documented in day2-handbook.md / day4-handbook.md. Change these
      # (or wire up NPMplus's own OIDC login) for anything beyond a throwaway lab VM.
      - "INITIAL_ADMIN_EMAIL=admin@learningsteps.local"
      - "INITIAL_ADMIN_PASSWORD=LearningSteps123!"

  crowdsec:
    container_name: crowdsec
    restart: unless-stopped
    image: docker.io/crowdsecurity/crowdsec:${CROWDSEC_IMAGE_TAG}
    network_mode: bridge
    ports:
      - "127.0.0.1:7422:7422"
      - "127.0.0.1:8080:8080"
    environment:
      - "TZ=Etc/UTC"
      - "USE_WAL=true"
      - "COLLECTIONS=ZoeyVid/npmplus crowdsecurity/appsec-crs"
    volumes:
      - "/opt/crowdsec/conf:/etc/crowdsec"
      - "/opt/crowdsec/data:/var/lib/crowdsec/data"
      - "/opt/npmplus/nginx/logs:/opt/npmplus/nginx/logs:ro"
EOF

# ── CrowdSec acquisition: nginx access log + AppSec listener ─────────────────
# NGINX_LOG path only exists once LOGROTATE=true has caused NPMplus to create it,
# but CrowdSec will pick it up on first tail once the file appears (idempotent).
#
# IMPORTANT finding from real testing: crowdsecurity/crs (the appsec-crs
# collection's ruleset) ships as an OUT-OF-BAND appsec-config upstream — see
# /etc/crowdsec/appsec-configs/crs.yaml inside the crowdsec container. That
# means it only scores/alerts *after* the request already went to the app; it
# never blocks the current request (this matches its own hub label, "WAF:
# Non-Blocking OWASP Core Rule Set" — it says non-blocking because it IS
# non-blocking by design, not just non-blocking-by-default-but-configurable).
# To get the "SQLi/XSS payload gets 403'd" demo the course wants, this script
# writes a custom appsec-config (crs-inband.yaml) that loads the same CRS
# rule content in-band (synchronous, blocking) instead. This is a deliberate
# deviation from CrowdSec's own recommended config — documented here and in
# day4-handbook.md as a "read the fine print" teaching moment in itself.
echo "==> Writing CrowdSec appsec-config override (CRS running in-band/blocking)..."
cat > /opt/crowdsec/conf/appsec-configs/crs-inband.yaml << 'EOF'
name: crowdsecurity/crs-inband
default_remediation: ban
inband_rules:
 - crowdsecurity/crs
EOF

echo "==> Writing CrowdSec acquisition config..."
cat > /opt/crowdsec/conf/acquis.d/npmplus.yaml << 'EOF'
---
filenames:
  - /opt/npmplus/nginx/*.log
labels:
  type: npmplus
---
filenames:
  - /opt/npmplus/nginx/*.log
labels:
  type: modsecurity
---
listen_addr: 0.0.0.0:7422
appsec_configs:
  - crowdsecurity/appsec-default
  - crowdsecurity/crs-inband
name: appsec
source: appsec
labels:
  type: appsec
EOF

# ── NPMplus-side bouncer config (disabled until the Day 2 WAF demo) ──────────
# Format confirmed by real testing: ENABLED + API_URL + APPSEC_URL + API_KEY.
# (docs.crowdsec.net's quickstart implies just ENABLED+API_KEY is enough, but
# without explicit API_URL/APPSEC_URL the npmplus container logs "Neither
# API_URL or APPSEC_URL are defined, remediation component will not do
# anything" and nothing is actually wired — confirmed by testing, documented
# here and in day4-handbook.md troubleshooting.)
if [ ! -f /opt/npmplus/crowdsec/crowdsec.conf ]; then
    echo "==> Writing default (disabled) CrowdSec bouncer config for NPMplus..."
    cat > /opt/npmplus/crowdsec/crowdsec.conf << 'EOF'
ENABLED=false
API_URL=http://127.0.0.1:8080
APPSEC_URL=http://127.0.0.1:7422
API_KEY=
EOF
fi

echo "==> Pulling images and starting NPMplus + CrowdSec..."
cd /opt/npmplus
docker compose pull
docker compose up -d

echo "==> Waiting for CrowdSec API to come up..."
for _ in $(seq 1 20); do
    if docker exec crowdsec cscli lapi status >/dev/null 2>&1; then
        break
    fi
    sleep 3
done
docker exec crowdsec cscli hub update || true
docker exec crowdsec cscli collections install crowdsecurity/appsec-crs || true

echo ""
echo "============================================================"
echo " NPMplus baseline is up."
echo "   Admin GUI  : https://<vm-ip>:81  (SSH tunnel recommended — see handbook)"
echo "   Initial admin login: admin@learningsteps.local / LearningSteps123!"
echo "   CrowdSec   : running, collections installed, bouncer NOT yet wired (WAF is off)"
echo "============================================================"

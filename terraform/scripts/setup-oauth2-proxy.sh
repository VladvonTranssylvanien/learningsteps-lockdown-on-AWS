#!/bin/bash
# Day 3 baseline — install oauth2-proxy binary + systemd unit (NOT started)
#
# Only installs the binary and a systemd unit template. The actual OIDC wiring
# (Entra ID app registration, client id/secret, issuer URL) is the live Day 3
# classroom demo — see handbook.md Day 3 — because that
# az ad app create walkthrough IS the day's teaching content, not boilerplate
# to automate away.
#
# After the live demo fills in /etc/oauth2-proxy/oauth2-proxy.env, start with:
#   sudo systemctl enable --now oauth2-proxy
#
# Usage (direct SSH):
#   scp -i .learningsteps_key scripts/setup-oauth2-proxy.sh azureuser@<vm-ip>:/tmp/
#   ssh -i .learningsteps_key azureuser@<vm-ip> "sudo bash /tmp/setup-oauth2-proxy.sh"

set -euo pipefail

OAUTH2_PROXY_VERSION="7.7.1"
ARCH="amd64"

echo "==> Installing oauth2-proxy v${OAUTH2_PROXY_VERSION}..."
if [ ! -x /usr/local/bin/oauth2-proxy ]; then
    TARBALL="oauth2-proxy-v${OAUTH2_PROXY_VERSION}.linux-${ARCH}.tar.gz"
    curl -fsSL -o "/tmp/${TARBALL}" \
        "https://github.com/oauth2-proxy/oauth2-proxy/releases/download/v${OAUTH2_PROXY_VERSION}/${TARBALL}"
    tar -xzf "/tmp/${TARBALL}" -C /tmp
    install -m 0755 "/tmp/oauth2-proxy-v${OAUTH2_PROXY_VERSION}.linux-${ARCH}/oauth2-proxy" /usr/local/bin/oauth2-proxy
fi
echo "    $(oauth2-proxy --version)"

mkdir -p /etc/oauth2-proxy
if [ ! -f /etc/oauth2-proxy/oauth2-proxy.env ]; then
    echo "==> Writing placeholder env file (fill in during the Day 3 live demo)..."
    cat > /etc/oauth2-proxy/oauth2-proxy.env << 'EOF'
# Fill these in during the Day 3 live demo, after:
#   az ad app create --display-name learningsteps-oauth2-proxy \
#       --sign-in-audience AzureADMyOrg \
#       --identifier-uris api://$APP_ID
# then: az ad app credential reset --id $APP_ID
OAUTH2_PROXY_CLIENT_ID=
OAUTH2_PROXY_CLIENT_SECRET=
OAUTH2_PROXY_OIDC_ISSUER_URL=https://login.microsoftonline.com/TENANT_ID/v2.0
OAUTH2_PROXY_COOKIE_SECRET=
# api://$APP_ID — same value as the app registration's identifier URI. Lets
# oauth2-proxy validate a bearer token (az account get-access-token
# --resource api://$APP_ID) directly, without a browser session — used to
# verify the auth flow end-to-end (see handbook.md Day 3, Demo 4).
OAUTH2_PROXY_OIDC_EXTRA_AUDIENCES=
OAUTH2_PROXY_SKIP_JWT_BEARER_TOKENS=true
EOF
fi

echo "==> Writing systemd unit..."
cat > /etc/systemd/system/oauth2-proxy.service << 'EOF'
[Unit]
Description=oauth2-proxy (Entra ID auth in front of FastAPI, behind NPMplus Auth Request)
After=network.target learningsteps.service

[Service]
Type=simple
EnvironmentFile=/etc/oauth2-proxy/oauth2-proxy.env
ExecStart=/usr/local/bin/oauth2-proxy \
    --http-address=127.0.0.1:4180 \
    --upstream=http://127.0.0.1:8000 \
    --provider=oidc \
    --redirect-url=https://REPLACE_WITH_DOMAIN/oauth2/callback \
    --email-domain=* \
    --skip-provider-button=true \
    --reverse-proxy=true \
    --pass-authorization-header=true
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Not a random cookie secret by default — generate one now so it's ready,
# instructor only needs to fill client id/secret/issuer during the live demo.
if grep -q '^OAUTH2_PROXY_COOKIE_SECRET=$' /etc/oauth2-proxy/oauth2-proxy.env; then
    SECRET=$(python3 -c "import secrets,base64; print(base64.urlsafe_b64encode(secrets.token_bytes(32)).decode())")
    sed -i "s#^OAUTH2_PROXY_COOKIE_SECRET=.*#OAUTH2_PROXY_COOKIE_SECRET=${SECRET}#" /etc/oauth2-proxy/oauth2-proxy.env
fi

systemctl daemon-reload

echo ""
echo "============================================================"
echo " oauth2-proxy installed but NOT started (no OIDC creds yet)."
echo " Live demo steps: fill in /etc/oauth2-proxy/oauth2-proxy.env"
echo " and the --redirect-url domain in the unit file, then:"
echo "   sudo systemctl daemon-reload"
echo "   sudo systemctl enable --now oauth2-proxy"
echo " Then in NPMplus GUI: Proxy Host -> Auth Request -> oauth2proxy"
echo "============================================================"

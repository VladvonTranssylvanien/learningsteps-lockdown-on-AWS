#!/bin/bash
# Exports CrowdSec decision countries as CloudWatch custom metrics,
# giving a lightweight geographic view of blocked attackers -
# equivalent to the Sentinel Workbook geographic visualization bonus
# from the Azure original project. Country code is read from the
# decision's "source.cn" field (confirmed via live JSON inspection),
# not a top-level "country" field.
set -euo pipefail

REGION="eu-central-1"
NAMESPACE="LearningSteps/CrowdSec"

docker exec crowdsec cscli decisions list -o json 2>/dev/null | \
  python3 -c "
import json, sys, subprocess
from collections import Counter

data = json.load(sys.stdin)
if not data:
    sys.exit(0)

countries = Counter()
for d in data:
    source = d.get('source', {})
    c = source.get('cn') or 'Unknown'
    countries[c] += 1

for country, count in countries.items():
    subprocess.run([
        'aws', 'cloudwatch', 'put-metric-data',
        '--region', '$REGION',
        '--namespace', '$NAMESPACE',
        '--metric-name', 'BlockedAttackers',
        '--dimensions', f'Country={country}',
        '--value', str(count)
    ])
"
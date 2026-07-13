# LearningSteps Lockdown — AWS Edition

<div align="center">

![AWS](https://img.shields.io/badge/AWS-Terraform-orange?logo=amazonaws)
![Terraform](https://img.shields.io/badge/IaC-Terraform-844FBA?logo=terraform)
![Security](https://img.shields.io/badge/Focus-Zero%20Trust%20Hardening-critical)
![Status](https://img.shields.io/badge/Status-Complete-brightgreen)
![Cost](https://img.shields.io/badge/AWS%20Cost-%240%20(Free%20Tier)-blue)
![Multi-Cloud](https://img.shields.io/badge/Multi--Cloud-Azure%20%E2%86%92%20AWS-6A1B9A)

</div>

---

## 📋 Executive Summary

A **Zero Trust security hardening** of the LearningSteps API, rebuilt on **AWS** as a direct architectural translation of a five-day Azure security project.

**Key Achievements:**
- ✅ **5-day security implementation** — Management Access → TLS/WAF → Identity → Data Isolation → Monitoring
- ✅ **100% Terraform-managed** — Full infrastructure as code
- ✅ **Zero-cost design** — All resources within AWS Free Tier limits
- ✅ **Real attack validation** — System caught and blocked an unplanned, genuine attacker during testing
- ✅ **Multi-cloud expertise** — Documented Azure ↔ AWS service mapping with comparative analysis

**Same application, same threat model — different cloud, different primitives.** This is not a copy-paste port; every piece was re-derived from first principles for AWS.

---

## 📚 Table of Contents

- [Executive Summary](#-executive-summary)
- [Architecture Overview](#-architecture-overview)
- [What Was Built](#-what-was-built)
- [Azure → AWS Service Mapping](#-azure--aws-service-mapping)
- [Comparative Analysis](#-comparative-analysis)
- [Challenges & Lessons Learned](#-challenges--lessons-learned)
- [Zero-Cost Design](#-zero-cost-design)
- [Implementation Journey](#-implementation-journey)
- [Technical Deep Dive](#-technical-deep-dive)
- [Beyond Requirements](#-beyond-requirements)
- [Repository Structure](#-repository-structure)
- [Deployment Guide](#-deployment-guide)
- [Teardown](#-teardown)
- [Skills Demonstrated](#-skills-demonstrated)

---

## 🏗️ Architecture Overview

```mermaid
graph TB
    Internet((🌐 Internet))

    subgraph VPC["VPC 10.0.0.0/16"]
        subgraph AppSubnet["subnet-app 10.0.1.0/24"]
            NACL["🛡️ Network ACL<br/>SSH restricted<br/>Auto-block deny rules"]
            SG_APP["🔒 Security Group<br/>SSH: admin IP only"]
            EC2["💻 EC2 t3.small<br/>NPMplus + CrowdSec<br/>oauth2-proxy + FastAPI"]
        end
        subgraph DBSubnet["subnet-db-secondary 10.0.2.0/24"]
            RDS[("🗄️ RDS PostgreSQL<br/>publicly_accessible = false<br/>storage_encrypted = true")]
        end
    end

    Cognito["👤 Amazon Cognito<br/>User Pool + App Client"]
    Secrets["🔐 Secrets Manager<br/>DB password"]
    Lambda["⚡ Lambda<br/>WAF attack detector"]
    CW["📊 CloudWatch<br/>Logs + Alarms + Dashboard"]
    CT["📝 CloudTrail<br/>Multi-region audit"]
    SNS["📧 SNS<br/>Security alerts"]
    EIP["📍 Elastic IP<br/>Stable address"]

    Internet -->|HTTPS| EIP --> NACL --> SG_APP --> EC2
    EC2 -->|IAM Role| Secrets
    EC2 -->|OIDC| Cognito
    EC2 -->|JSON logs| CW
    CW -->|EventBridge 5min| Lambda
    Lambda -->|auto-block| NACL
    EC2 -.->|private| RDS
    CT -->|security metrics| SNS
```

### Security Layers (Defense in Depth)

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Edge** | CrowdSec + OWASP CRS | Real-time WAF blocking (milliseconds) |
| **Network** | Network ACL | Stateless deny rules, auto-blocking |
| **Compute** | Security Group | Stateful allow rules, SSH restriction |
| **Identity** | Cognito + oauth2-proxy | Authentication & authorization |
| **Data** | RDS (private) + Secrets Manager | Encrypted at rest, credential isolation |
| **Monitoring** | CloudWatch + CloudTrail | Detection, alerting, audit |

---

## 🚀 What Was Built

| Component | Details |
|-----------|---------|
| **Network** | Custom VPC, public subnet, Internet Gateway, route table, Security Group, Network ACL |
| **Compute** | EC2 `t3.small` (Ubuntu 22.04) with `cloud-init` — fully automated provisioning |
| **Database** | RDS PostgreSQL 16, encrypted at rest, private (no public access) |
| **Identity** | Cognito User Pool (email username) + App Client, oauth2-proxy integration |
| **Edge** | NPMplus (reverse proxy) + CrowdSec (OWASP CRS WAF), Let's Encrypt TLS |
| **Secrets** | AWS Secrets Manager — RDS password via IAM Role (no static credentials) |
| **Detection** | CloudWatch Logs + Lambda (every 5 min) → Network ACL auto-block |
| **Audit** | Multi-region CloudTrail → S3 + CloudWatch, IAM Access Analyzer |
| **Alerting** | CloudWatch Alarms → SNS (root usage, IAM changes, MFA policy) |
| **Visibility** | CloudWatch Dashboard — geo-attack map, WAF timeseries, block table |
| **Stability** | Elastic IP (survives EC2 stop/start), Resource Group, hardened S3 bucket |

---

## 🔄 Azure → AWS Service Mapping

| Concept | Azure (Original) | AWS (This Project) | Key Difference |
|---------|------------------|-------------------|----------------|
| **Compute** | Azure VM (Standard_D2s_v3) | EC2 (t3.small) | Naming, sizing |
| **Network** | Azure VNet + NSG | VPC + Security Group + Network ACL | NSG = SG + NACL combined |
| **Management Access** | Entra ID (AADSSHLoginForLinux) | IAM Role + SSM Session Manager | No extension needed on AWS |
| **Reverse Proxy/WAF** | NPMplus + CrowdSec | NPMplus + CrowdSec | **Identical** (cloud-agnostic) |
| **Identity Provider** | Microsoft Entra ID | Amazon Cognito | Different service, same concept |
| **Database** | Azure PostgreSQL Flexible | RDS for PostgreSQL | Similar, different naming |
| **DB Network Isolation** | VNet Integration (ForceNew) | `publicly_accessible = false` (in-place) | **AWS is mutable** |
| **Secrets** | Key Vault + Managed Identity | Secrets Manager + IAM Role | Similar pattern |
| **SIEM/Detection** | Microsoft Sentinel + KQL | CloudWatch Logs Insights + Lambda | AWS = build-your-own |
| **Automated Response** | Logic App | Lambda + boto3 | AWS = code, Azure = low-code |
| **Audit Trail** | Azure Activity Log | CloudTrail (multi-region) | AWS more comprehensive |
| **Alerting** | Sentinel Automation | CloudWatch Alarms + SNS | Different approach |
| **DNS (Free)** | `domain_name_label` (Azure FQDN) | `nip.io` (third-party) | **AWS lacks free FQDN** |
| **Stable IP** | Static Public IP | Elastic IP | Equivalent |

---

## 📊 Comparative Analysis

### ✅ What's Better on AWS

**1. RDS Network Migration is Non-Destructive**

| Aspect | Azure | AWS |
|--------|-------|-----|
| **Operation** | VNet Integration | `publicly_accessible = false` |
| **Effect** | **ForceNew** — destroys/recreates DB | **In-place update** — no downtime |
| **Impact** | Requires backup/restore for Day 4 | Optional discipline, not mandatory |

**2. SSM Session Manager — No Extension Required**

| Aspect | Azure (AADSSHLogin) | AWS (SSM) |
|--------|---------------------|-----------|
| **Installation** | Explicit extension install | **Pre-installed** on AMI |
| **Dependencies** | Requires VM public IP | Works via IAM Role |
| **Failure Mode** | Can silently fail | Reliable by design |

**3. IAM Least-Privilege is Cleaner**
- Lambda only needed 2 permissions: `DescribeNetworkAcls` and `CreateNetworkAclEntry`
- No over-permissioning, easy to reason about

**4. CloudTrail is Genuinely Free**
- No cost at the tier used
- Multi-region by default
- Industry-standard skill

### ❌ What's Worse or Harder on AWS

**1. No Free FQDN for EC2**

| Aspect | Azure | AWS |
|--------|-------|-----|
| **Free DNS** | `domain_name_label` | **None** |
| **Solution** | Built-in | `nip.io` (third-party) |

**2. Security Groups Have NO Deny Rules**

| Aspect | Azure NSG | AWS Security Group |
|--------|-----------|-------------------|
| **Allow Rules** | ✅ Yes | ✅ Yes |
| **Deny Rules** | ✅ Yes (with priorities) | ❌ **No** |

**3. RDS Multi-AZ Subnet Requirement**
- Even for a **single-AZ instance**
- Required creating a second, otherwise-unused subnet

**4. Free Tier Limitations**

| Service | Free Tier Availability |
|---------|----------------------|
| **GuardDuty** | ❌ Requires Paid Plan |
| **Security Hub** | ❌ Requires Paid Plan |
| **AWS WAF** | ❌ Costs per request |

---

## 🧠 Challenges & Lessons Learned

### 🔥 Challenges Encountered

**Challenge 1: CrowdSec Blocking Its Own Admin**
- **Problem:** WAF inspected SSM-tunneled admin panel access on port 81; admin actions misclassified as attacks
- **Solution:** Dedicated CrowdSec allowlist
- **Lesson:** Cloud-native security tooling needs explicit allowlisting for its own management traffic

**Challenge 2: CloudWatch Logs Insights Parsing Failure**
- **Problem:** rsyslog writing syslog-prefixed lines instead of clean JSON
- **Solution:** rsyslog template `%msg:2:$%` strips the prefix
- **Lesson:** Log formatting matters — test your parsers early

**Challenge 3: Attacker Geolocation Field Undocumented**
- **Problem:** CrowdSec exposes country as `source.cn`, not a top-level `country` field
- **Solution:** Dumped and inspected raw JSON directly
- **Lesson:** Always verify data structures yourself

**🏆 Challenge 4: Real Attacker During Testing**
- **Scenario:** While validating the auto-block pipeline, Lambda caught and blocked a genuine attacker
- **Significance:** Unplanned but strong live confirmation the pipeline works

### 📝 Lessons Learned

1. **Mutability vs. ForceNew is a real architectural signal** — changes whether hardening requires backup plans
2. **Cloud-native tooling needs management traffic whitelisted explicitly** — design for this from day one
3. **Free-tier boundaries are real constraints** — not having GuardDuty meant building custom detection logic
4. **Translating between clouds is a different skill** — cloud-agnostic parts transfer cleanly; cloud-specific parts require real rework

---

## 💰 Zero-Cost Design

| Decision | Cost Impact | Why It Matters |
|----------|-------------|----------------|
| `nip.io` instead of paid domain | **$0** (vs ~$12/year) | No DNS setup, trusted Let's Encrypt |
| **No NAT Gateway** | **$0** (vs ~$35/month) | Biggest hidden cost trap |
| RDS capped at 20GB | **Free** (Free Tier limit) | Azure original used 32GB |
| **CrowdSec** instead of AWS WAF | **$0** (vs per-request cost) | Self-hosted, same protection |
| **Elastic IP** (attached) | **$0** (free while attached) | Prevents TLS/callback breaks |

---

## 👣 Implementation Journey

### Day 1 — Management Access
**Goal:** Secure administrative access without SSH keys.

| What Was Built | Why It Matters |
|----------------|----------------|
| SSM Session Manager | No SSH keys, no bastion host |
| IAM Role-based access | Centralized permission management |
| Security Group restriction | Network-layer control |

<details>
<summary>📸 Screenshots</summary>

![SSM login](docs/screenshots/day1-ssm-login.png)
*SSM session established without SSH keys*

![Security Group](docs/screenshots/day1-security-group.png)
*SSH restricted to admin IP only*

</details>

### Day 2 — TLS & WAF
**Goal:** Encrypted traffic and web application firewall.

| What Was Built | Why It Matters |
|----------------|----------------|
| Let's Encrypt TLS on NPMplus | Encrypted HTTPS traffic |
| CrowdSec + OWASP CRS | Real-time attack blocking |
| OWASP Top 10 protection | Industry-standard rules |

<details>
<summary>📸 Screenshots</summary>

![NPMplus TLS](docs/screenshots/day2-npmplus-tls.png)
*TLS certificate configured in NPMplus*

![TLS verified](docs/screenshots/day2-tls-verified.png)
*HTTPS connection verified*

![WAF block](docs/screenshots/day2-waf-block.png)
*WAF blocking malicious request*

</details>

### Day 3 — Identity
**Goal:** User authentication and authorization.

| What Was Built | Why It Matters |
|----------------|----------------|
| Cognito User Pool | Managed identity provider |
| oauth2-proxy integration | OIDC authentication for app |
| Email-based sign-up | Simple user management |

<details>
<summary>📸 Screenshots</summary>

![Authenticated app](docs/screenshots/day3-authenticated-app.png)
*OAuth2-authenticated session reaching the app*

</details>

### Day 4 — Data Isolation
**Goal:** Database secured from public internet.

| What Was Built | Why It Matters |
|----------------|----------------|
| RDS `publicly_accessible = false` | No public DB access |
| Security Group restriction | Only app tier can connect |
| Encryption at rest | Data protection |

<details>
<summary>📸 Screenshots</summary>

![RDS private](docs/screenshots/day4-rds-private.png)
*RDS set to private — no public access*

![Data intact](docs/screenshots/day4-data-intact.png)
*Application still accessing database*

![Connection failed from laptop](docs/screenshots/day4-connection-failed.png)
*Direct DB connection from laptop blocked*

</details>

### Day 5 — Detection & Response
**Goal:** Automated threat detection and response.

| What Was Built | Why It Matters |
|----------------|----------------|
| CloudWatch Logs Insights | Log analysis queries |
| Lambda auto-blocker | Automated response |
| CloudWatch Dashboard | Visibility dashboard |

<details>
<summary>📸 Screenshots</summary>

![CloudWatch Logs Insights](docs/screenshots/day5-logs-insights.png)
*Query identifying attackers*

![Network ACL block](docs/screenshots/day5-nacl-block.png)
*Network ACL deny rule added automatically*

![Dashboard](docs/screenshots/day5-dashboard.png)
*Dashboard showing blocked attackers and geolocation*

</details>

---

## 🔬 Technical Deep Dive

### How Attacker Detection Works

The detection pipeline runs on **two parallel tracks** feeding the same Network ACL:

**1. WAF-Level Blocking (CrowdSec — Real-Time)**
```
HTTP Request → NPMplus → Lua inspection → CrowdSec Decision Engine
                                    ↓
                            OWASP CRS + Behavioral Rules
                                    ↓
                            Match? → 403 (milliseconds)
```

**2. Log-Based Detection (Lambda — Every 5 Minutes)**
```
nginx → JSON logs → syslog → rsyslog cleanup → CloudWatch Agent
                                                    ↓
                                            CloudWatch Log Group
                                                    ↓
                                        EventBridge (every 5 min)
                                                    ↓
                                    Lambda: Logs Insights Query
                                            ↓
                            COUNT(403) per IP over 5 min > 5
                                            ↓
                                    ec2:CreateNetworkAclEntry
                                            ↓
                                Deny rule at priority < 100
```

### Geolocation Pipeline

```
CrowdSec Decision → MaxMind GeoIP → source.cn field → cscli export
                                                           ↓
                                            geo-export/export-geo-metrics.sh
                                                           ↓
                                            CloudWatch Custom Metric
                                            (BlockedAttackers per Country)
                                                           ↓
                                                    Dashboard Pie Chart
```

**Key Insight:** AWS never performs IP-to-country lookup; CrowdSec does it internally.

---

## 🌟 Beyond Requirements

*Added after the five required days to reflect real-world Cloud Security Engineering — all still within $0 Free Tier.*

| Feature | Why It Matters |
|---------|----------------|
| **AWS Secrets Manager** | Azure Key Vault equivalent |
| **CloudTrail (multi-region)** | Complete audit trail |
| **CloudWatch Alarms + SNS** | Real-time email alerts |
| **IAM Access Analyzer** | Continuous permission review |
| **RDS Encryption at Rest** | Data protection (forced backup/restore test) |
| **MFA-Required IAM Policy** | Denies actions without MFA |
| **Fully Reproducible Provisioning** | `terraform destroy` + `apply` = complete rebuild |

---

## 📁 Repository Structure

```
terraform/
├── 📄 provider.tf                  # AWS + archive providers
├── 📄 variables.tf                 # Region, prefix, credentials
├── 📄 main.tf                      # Shared locals (tags)
├── 📄 network.tf                   # VPC, subnet, IGW, route table, SG
├── 📄 ec2.tf                       # EC2 instance, AMI, Elastic IP
├── 📄 iam.tf                       # VM IAM role, SSM policy
├── 📄 rds.tf                       # RDS instance, DB subnet group
├── 📄 cognito.tf                   # User Pool, App Client, Domain
├── 📄 secrets-manager.tf           # RDS password secret
├── 📄 monitoring.tf                # CloudWatch, Lambda, EventBridge
├── 📄 cloudtrail.tf                # Multi-region trail, S3 bucket
├── 📄 alerts.tf                    # SNS topic, metric filters, alarms
├── 📄 geo-dashboard.tf             # CloudWatch Dashboard
├── 📄 access-analyzer.tf           # IAM Access Analyzer
├── 📄 mfa-policy.tf                # MFA-required IAM policy
├── 📄 resource-group.tf            # Tag-based Resource Group
├── 📄 outputs.tf                   # VM IP, SSM command, DB endpoint
└── 📂 scripts/
    ├── 📄 cloud-init.yaml          # Full VM provisioning (idempotent)
    ├── 📄 setup-npmplus.sh         # Docker + NPMplus + CrowdSec
    ├── 📄 setup-json-logging.sh    # nginx access.log → syslog JSON
    ├── 📄 setup-cloudwatch-logging.sh  # rsyslog + CloudWatch Agent
    ├── 📂 geo-export/
    │   └── 📄 export-geo-metrics.sh     # CrowdSec → CloudWatch metrics
    └── 📂 waf-attack-detector/
        └── 📄 handler.py             # Lambda: query + NACL deny
```

---

## 🚀 Deployment Guide

### Prerequisites

- **AWS Account** (Free Tier recommended)
- **AWS CLI** configured with credentials
- **Terraform** (v1.0+)
- **IAM User** with sufficient permissions

### Quick Start

```bash
# 1. Clone repository
git clone https://github.com/yourusername/learningsteps-lockdown-aws
cd learningsteps-lockdown-aws/terraform

# 2. Initialize Terraform
terraform init

# 3. Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your DB password and region

# 4. Deploy
terraform apply
# Review plan, type 'yes' to confirm
```

### Connect to Instance (No SSH Key Required)

```bash
# SSM session (no SSH key needed)
aws ssm start-session --target <instance-id> --region eu-central-1

# NPMplus admin panel (tunnel only — not exposed publicly)
aws ssm start-session --target <instance-id> --region eu-central-1 \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["81"],"localPortNumber":["8081"]}'
# Browse to https://localhost:8081
```

### Access the Application

1. Get the Elastic IP: `terraform output ec2_public_ip`
2. Open browser: `https://<elastic-ip>`
3. Sign up/login via Cognito
4. Access the FastAPI application

---

## 🗑️ Teardown

```bash
# Destroy everything (clean teardown)
terraform destroy

# Note: CloudTrail S3 bucket has force_destroy = true
# No manual cleanup required
```

---

## 🎯 Skills Demonstrated

### Cloud & Infrastructure

| Skill | Evidence |
|-------|----------|
| **AWS Services** | VPC, EC2, RDS, Cognito, IAM, CloudWatch, Lambda, Secrets Manager, CloudTrail, SNS, S3 |
| **Infrastructure as Code** | Complete Terraform implementation (12+ files) |
| **Multi-Cloud Translation** | Azure → AWS service mapping with comparative analysis |
| **Cost Optimization** | Zero-cost design within Free Tier limits |

### Security Engineering

| Skill | Evidence |
|-------|----------|
| **Zero Trust Architecture** | Defense in depth: WAF, Network ACL, SG, IAM, Encryption |
| **WAF Implementation** | CrowdSec + OWASP CRS (real-time blocking) |
| **Identity & Access** | Cognito + oauth2-proxy + MFA-required IAM policy |
| **Secrets Management** | AWS Secrets Manager with IAM Role (no static credentials) |
| **Threat Detection** | Automated Lambda-based attack detection |
| **Incident Response** | Auto-blocking via Network ACL rules |
| **Monitoring & Alerting** | CloudWatch Dashboard + SNS alerts |
| **Audit** | Multi-region CloudTrail + IAM Access Analyzer |

### Automation & DevOps

| Skill | Evidence |
|-------|----------|
| **Provisioning** | `cloud-init` with idempotent scripts |
| **Log Management** | JSON-formatted nginx logs → CloudWatch |
| **Automated Response** | EventBridge + Lambda (every 5 min) |
| **Reproducibility** | `terraform destroy` + `apply` = complete rebuild |

### Documentation & Communication

| Skill | Evidence |
|-------|----------|
| **Technical Writing** | Comprehensive README with architecture diagrams |
| **Problem Documentation** | Challenges Encountered + Lessons Learned |
| **Comparative Analysis** | Azure vs AWS "Better/Worse" sections |
| **Evidence** | Screenshots for each day |

---

## 🙏 Acknowledgments

- **Original Project:** [`learningsteps-lockdown`](https://github.com/VladvonTranssylvanien/learningsteps-lockdown) — the Azure implementation that inspired this work
- **Tools Used:** Terraform, AWS CLI, Docker, NPMplus, CrowdSec, oauth2-proxy, Python
- **Learning Resources:** AWS Documentation, Terraform Registry, CrowdSec Documentation

---

## 📝 License

This project is for educational purposes. Please review and adapt for your own learning.

---

<div align="center">

**Built with ❤️ for learning, security, and multi-cloud mastery.**

[⬆ Back to Top](#learningsteps-lockdown--aws-edition)

</div>

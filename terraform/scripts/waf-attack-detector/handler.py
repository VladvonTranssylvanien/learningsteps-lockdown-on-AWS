import boto3
import os
import time
import json

logs_client = boto3.client("logs")
ec2_client = boto3.client("ec2")

LOG_GROUP_NAME = os.environ["LOG_GROUP_NAME"]
NACL_ID = os.environ["NACL_ID"]
THRESHOLD = 5

QUERY = """
fields @timestamp, remote_addr, status
| filter status = 403
| filter remote_addr != "127.0.0.1"
| stats count(*) as waf_blocks by remote_addr
| filter waf_blocks >= 5
"""


def lambda_handler(event, context):
    start_query = logs_client.start_query(
        logGroupName=LOG_GROUP_NAME,
        startTime=int(time.time()) - 300,
        endTime=int(time.time()),
        queryString=QUERY,
    )
    query_id = start_query["queryId"]

    response = None
    for _ in range(10):
        response = logs_client.get_query_results(queryId=query_id)
        if response["status"] in ("Complete", "Failed", "Cancelled"):
            break
        time.sleep(1)

    if not response or response["status"] != "Complete":
        return {"status": "no_results"}

    blocked_ips = []
    for row in response["results"]:
        fields = {f["field"]: f["value"] for f in row}
        ip = fields.get("remote_addr")
        if ip:
            blocked_ips.append(ip)

    for ip in blocked_ips:
        block_ip(ip)

    return {"status": "ok", "blocked_ips": blocked_ips}


def block_ip(ip):
    nacls = ec2_client.describe_network_acls(NetworkAclIds=[NACL_ID])
    existing_rule_numbers = [
        entry["RuleNumber"]
        for entry in nacls["NetworkAcls"][0]["Entries"]
        if not entry["Egress"]
    ]
    next_rule_number = max([n for n in existing_rule_numbers if n < 100], default=0) + 1

    try:
        ec2_client.create_network_acl_entry(
            NetworkAclId=NACL_ID,
            RuleNumber=next_rule_number,
            Protocol="-1",
            RuleAction="deny",
            Egress=False,
            CidrBlock=f"{ip}/32",
        )
        print(f"Blocked {ip} with NACL rule {next_rule_number}")
    except ec2_client.exceptions.ClientError as e:
        print(f"Could not block {ip}: {e}")

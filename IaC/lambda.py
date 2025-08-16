import json, os, boto3, datetime, uuid

bedrock = boto3.client("bedrock-runtime", region_name=os.getenv("AWS_REGION", None))
s3      = boto3.client("s3")

MODEL_ID   = os.getenv("BEDROCK_MODEL_ID")
BUCKET     = os.getenv("KB_BUCKET")
PREFIX     = os.getenv("KB_PREFIX", "gd_summaries/")

def summarize_with_bedrock(finding):
    """Return a short SOC-oriented summary of a GuardDuty finding."""
    title   = finding.get("title") or finding.get("Title")
    sev     = (finding.get("severity") or finding.get("Severity") or 0)
    ftype   = finding.get("type") or finding.get("Type")
    account = finding.get("accountId") or finding.get("AccountId")
    region  = finding.get("region") or finding.get("Region")
    detail  = json.dumps(finding)

    prompt = f"""You are a SOC analyst. Summarize this AWS GuardDuty finding for analyst triage in 3 bullets:
- include severity (0-8), finding type, affected resources (if any), and suspected root cause.
- end with a 1-line remediation hint.
JSON:
{detail}"""

    payload = {
      "anthropic_version":"bedrock-2023-05-31",
      "max_tokens": 300,
      "temperature": 0.1,
      "messages":[{"role":"user","content":[{"type":"text","text":prompt}]}]
    }

    resp = bedrock.invoke_model(
        modelId=MODEL_ID,
        body=json.dumps(payload),
        accept="application/json",
        contentType="application/json",
    )

    body = resp["body"].read()
    out  = json.loads(body)

    # Anthropic messages format -> pull the text
    text = ""
    try:
        text = out["output"]["content"][0]["text"]
    except Exception:
        text = str(out)

    return {
        "summary": text,
        "severity": sev,
        "type": ftype,
        "accountId": account,
        "region": region,
        "title": title,
    }

def lambda_handler(event, context):
    # EventBridge delivers guardduty findings in detail
    # https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_findings.html
    detail = event.get("detail") or {}
    finding = detail.get("findings", [detail])[0]

    summary = summarize_with_bedrock(finding)

    # Store a JSONL record for future RAG/analytics
    now = datetime.datetime.utcnow().strftime("%Y-%m-%d")
    key = f"{PREFIX}{now}/{uuid.uuid4().hex}.jsonl"
    line = json.dumps({
        "ts": datetime.datetime.utcnow().isoformat() + "Z",
        "finding": finding,
        "triage": summary
    }) + "\n"

    s3.put_object(Bucket=BUCKET, Key=key, Body=line.encode("utf-8"))
    return {"status": "ok", "s3_key": key}

import os
import subprocess
import hashlib
from dotenv import load_dotenv
from langchain_community.llms import HuggingFacePipeline
from transformers import pipeline
from tools.fetch_logs import get_recent_logs
from elasticsearch import Elasticsearch
from datetime import datetime, timezone

# Load environment variables
load_dotenv()

# HuggingFace model
model_name = "google/flan-t5-base"
generator = pipeline(
    "text2text-generation",
    model=model_name,
    tokenizer=model_name,
    device=-1,   # CPU
    max_new_tokens=200
)
llm = HuggingFacePipeline(pipeline=generator)

# Elasticsearch client
es = Elasticsearch(hosts=[os.getenv("ELASTICSEARCH_HOST", "http://localhost:9200")])

def fake_ip_from_user(user):
    """Generate a deterministic fake IP from username (simulation)."""
    if not user:
        return "192.168.0.1"
    h = hashlib.md5(user.encode()).hexdigest()
    return f"10.{int(h[0:2],16)%255}.{int(h[2:4],16)%255}.{int(h[4:6],16)%255}"

def decide_action(log):
    """Enhanced rule-based mapping from event_type & severity."""
    event = (log.get("event_type") or "").strip().lower()
    severity = (log.get("severity") or "").strip().lower()

    # 🚨 Always block these regardless of severity
    if event in ["sshbruteforce", "s3unauthorizedaccess", "blobaccessdenied"]:
        return "block_ip"

    if event == "portscan":
        if severity in ["critical", "high", "medium"]:
            return "isolate_vm"
        else:
            return "alert_only"

    if event == "maliciousdomainrequest":
        if severity in ["critical", "high"]:
            return "block_ip"
        else:
            return "alert_only"

    # Default safe option: raise an alert
    return "alert_only"

def generate_explanation(log, action):
    """Generate SOC-style explanation with fallback."""
    clean_log = f"""
    Event Type: {log.get('event_type')}
    Severity: {log.get('severity')}
    User: {log.get('user')}
    Source: {log.get('source')}
    Message: {log.get('message')}
    """

    prompt = f"""
    You are a SOC analyst AI. Analyze the following log entry.

    Security Log:
    {clean_log}

    Explain in 3–4 sentences:
    - The type of attack
    - Why severity matters
    - Risks posed
    - Why action '{action}' mitigates the risk
    """

    try:
        explanation = llm.invoke(prompt).strip().replace("\n", " ")

        if explanation.lower().count(action.lower()) > 3 or len(explanation.split()) < 12:
            return (f"A {log.get('event_type')} attack with severity {log.get('severity')} "
                    f"was detected against user {log.get('user')} from {log.get('source')}. "
                    f"This type of activity can compromise critical resources. "
                    f"The action '{action}' ensures the threat is neutralized.")
        return explanation
    except Exception as e:
        return f"⚠️ Failed to generate explanation: {e}"

def execute_action(action, user):
    """Run the responder shell script with a fake IP."""
    fake_ip = fake_ip_from_user(user)
    result = subprocess.getoutput(f"bash tools/action.sh {action} {fake_ip}")
    print(f"✅ Action taken: {action}\n{result}")
    return result

def log_decision_to_es(action, log, explanation):
    """Save agent decisions back to Elasticsearch."""
    doc = {
        "@timestamp": datetime.now(timezone.utc).isoformat(),
        "agent_action": action,
        "event_type": log.get("event_type"),
        "severity": log.get("severity"),
        "user": log.get("user"),
        "message": log.get("message"),
        "explanation": explanation,
        "critical_action_taken": action in ["block_ip", "isolate_vm"]
    }
    es.index(index="agent-decisions", document=doc)
    print("📌 Decision logged to Elasticsearch")

if __name__ == "__main__":
    logs = get_recent_logs(5)
    print(f"✅ Pulled {len(logs)} logs from Elasticsearch")

    for log in logs:
        print(f"\n🔎 Log: {log.get('message')}")
        action = decide_action(log)

        if action != "no_action":
            explanation = generate_explanation(log, action)
            print("🧠 Explanation:", explanation)

            execute_action(action, log.get("user"))
            log_decision_to_es(action, log, explanation)
        else:
            print("ℹ️ No action needed for this log.")


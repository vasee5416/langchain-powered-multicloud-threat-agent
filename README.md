# LangChain-Powered Multi-Cloud Threat Detection Agent

This project combines a **LangChain-powered AI Agent** with a **Multi-Cloud Threat Detection System for AWS and Azure**.  
It provides real-time log analysis, decision-making, and automated responses for security events from AWS and Azure environments.  
All components are designed to run locally on Kali Linux using Elasticsearch, Logstash, and Kibana (ELK Stack).

---

## 🚀 Features

- **AI Agent (LangChain + HuggingFace)**
  - Analyzes security logs from AWS and Azure
  - Generates human-readable explanations for detected threats
  - Takes automated response actions (`block_ip`, `alert_only`, etc.)
  - Logs every decision back into Elasticsearch for audit and visualization

- **Multi-Cloud Threat Detection**
  - Centralized log ingestion from AWS GuardDuty & Azure Defender
  - Custom Logstash pipelines for log normalization
  - Pre-built Kibana dashboards for monitoring
  - Supports continuous monitoring & alerting

- **Visualization**
  - Kibana dashboards for:
    - 📊 Timeline of Alert Events
    - 🔎 Top Event Types & Affected Users
    - 🛡️ Severity Trends Over Time
    - 🚦 Agent Decisions (from AI analysis)

---

## 📂 Project Structure
multi-cloud-threat-detection/
│
├── README.md
├── LICENSE
├── .gitignore
│
├── architecture/
│   └── architecture_diagram.png              # Overall architecture diagram (AWS + Azure → Logstash → Elasticsearch → Kibana)
│
├── logstash/
│   ├── multicloud-logs.conf                  # Logstash pipeline config (parsing + filters)
│
├── scripts/
│   ├── fetch_aws_logs.sh                     # Bash script to pull AWS GuardDuty / CloudTrail logs
│   ├── fetch_azure_logs.sh                   # Bash script to pull Azure Defender / Blob logs
│
├── logs/
│   ├── aws_guardduty_sample.json             # Sample AWS GuardDuty logs
│   ├── azure_defender_sample.json            # Sample Azure Defender logs
│
├── dashboards/
│   ├── kibana_dashboard_export.ndjson        # Exported Kibana dashboard
│   └── screenshots/
│       ├── timeline.png                      # Timeline of threat events
│       └── top-alerts.png                    # Top alert categories visualization



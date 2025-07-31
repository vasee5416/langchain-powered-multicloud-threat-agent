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

```plaintext
multi-cloud-threat-detection/
│
├── README.md                      # Documentation for the detection project
├── LICENSE                        # Project license (MIT)
├── .gitignore                     # Files/folders ignored by Git
│
├── architecture/
│   └── architecture_diagram.png   # Overall architecture diagram 
│                                  # (AWS + Azure → Logstash → Elasticsearch → Kibana)
│
├── logstash/
│   ├── multicloud-logs.conf       # Logstash pipeline config (filters & parsing rules)
│
├── scripts/
│   ├── fetch_aws_logs.sh          # Bash script to pull AWS GuardDuty / CloudTrail logs
│   ├── fetch_azure_logs.sh        # Bash script to pull Azure Defender / Blob logs
│
├── logs/
│   ├── aws_guardduty_sample.json  # Sample AWS GuardDuty logs
│   ├── azure_defender_sample.json # Sample Azure Defender logs
│
├── dashboards/
│   ├── kibana_dashboard_export.ndjson # Exported Kibana dashboard for quick import
│   └── screenshots/
│       ├── timeline.png           # Timeline of threat events
│       └── top-alerts.png         # Top alert categories visualization
│
└── report/
    └── Multicloud_Threat_Detection_Report.pdf # Final project report

## 🏗 System Architecture Diagram

```mermaid
flowchart TD
    subgraph AWS[AWS Cloud]
        GD[GuardDuty Logs]
        CT[CloudTrail Logs]
        S3[S3 Storage]
    end

    subgraph Azure[Azure Cloud]
        DEF[Defender for Cloud Alerts]
        BLOB[Blob Storage Logs]
        MON[Azure Monitor]
    end

    subgraph Ingestion[Ingestion Layer - Kali Linux VM]
        AWSCLI[fetch_aws_logs.sh<br>(AWS CLI)]
        AZCOPY[fetch_azure_logs.sh<br>(Azure CLI / AzCopy)]
    end

    subgraph Processing[Processing Layer - Logstash]
        CONF[multicloud-logs.conf<br>Parsing & Normalization]
        TAGS[Tagging Severity & Events]
    end

    subgraph Storage[Indexing & Storage - Elasticsearch]
        ES[Elasticsearch<br>multicloud-logs-*]
    end

    subgraph Visualization[Visualization - Kibana]
        DASH[Custom Dashboards<br>Timeline, Top Events, Severity Trends]
    end

    subgraph Agent[AI Agent - LangChain + HuggingFace]
        FETCH[Fetch Logs via Elasticsearch]
        ANALYZE[Analyze Threats<br>LLM Processing]
        ACTION[Execute Actions<br>(actions.sh / iptables)]
        DECISION[Log Decisions Back<br>to Elasticsearch]
    end

    AWS -->|Logs| Ingestion
    Azure -->|Logs| Ingestion
    Ingestion -->|Parsed Logs| Processing
    Processing -->|Normalized Data| Storage
    Storage --> Visualization
    Storage --> Agent
    Agent -->|Mitigation| ACTION
    Agent -->|Log Decisions| Storage



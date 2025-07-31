# LangChain-Powered Multi-Cloud Threat Detection Agent

This project implements an **agentic AI system** for detecting and mitigating security threats across **AWS** and **Azure** environments.  
It combines **LangChain** + HuggingFace LLMs with **Elasticsearch** and **Kibana** to provide automated detection, response, and visualization.

---

## Features
- Pulls multi-cloud logs from **Elasticsearch**
- Analyzes logs with **LangChain** + HuggingFace AI
- Generates **SOC-style explanations** for each threat
- Executes automated responses:
  - `block_ip`
  - `isolate_vm`
  - `alert_only`
- Logs decisions back into Elasticsearch
- Provides a Kibana dashboard for monitoring agent activity

---

## Example Agent Workflow
- Detects a **SSHBruteForce** attempt → Blocks attacker IP
- Detects a **MaliciousDomainRequest** → Raises alert only
- Detects **BlobAccessDenied** or **Unauthorized S3 Access** → Blocks attacker

---

## Setup

### 1. Clone Repository
```bash
git clone https://github.com/YOUR-USERNAME/langchain-multicloud-threat-agent.git
cd langchain-multicloud-threat-agent


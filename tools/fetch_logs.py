import os
from elasticsearch import Elasticsearch
from dotenv import load_dotenv

load_dotenv()

es = Elasticsearch(
    hosts=[os.getenv("ELASTICSEARCH_HOST", "http://localhost:9200")],
    headers={"Accept": "application/vnd.elasticsearch+json; compatible-with=8"}
)

def get_recent_logs(limit=20):
    response = es.search(
        index=os.getenv("ELASTICSEARCH_INDEX", "multicloud-logs-*"),
        size=limit,
        body={"query": {"match_all": {}}}
    )
    return [hit["_source"] for hit in response["hits"]["hits"]]


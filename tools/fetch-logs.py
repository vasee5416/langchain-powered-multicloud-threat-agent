from elasticsearch import Elasticsearch
import os

es = Elasticsearch(os.getenv("ELASTICSEARCH_HOST"))

def get_recent_logs(minutes=5):
    from datetime import datetime, timedelta
    now = datetime.utcnow()
    start_time = now - timedelta(minutes=minutes)

    response = es.search(
        index=os.getenv("ELASTICSEARCH_INDEX"),
        body={
            "query": {
                "range": {
                    "@timestamp": {
                        "gte": start_time.isoformat(),
                        "lte": now.isoformat()
                    }
                }
            }
        }
    )
    logs = [hit['_source'] for hit in response['hits']['hits']]
    return logs


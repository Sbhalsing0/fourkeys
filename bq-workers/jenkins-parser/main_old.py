
import builtins
import hashlib
import json

from flask import Flask
from flask.globals import request
from google.cloud import bigquery
import datetime

app = Flask(__name__)


def process_jenkins_event(request):

    envelope = request.get_json()
    headers = dict(request.headers)
    source = "jenkins"
    body = request.data
    e_id = envelope.get("id")
    epoch = envelope.get("timestamp")/1000
    time_created = datetime.datetime.utcfromtimestamp(epoch).strftime('%Y-%m-%d %H:%M:%S')
    msg_id = envelope.get("number")
    actions = envelope.get("actions")
    main_commit = actions[4].get("lastBuiltRevision").get("SHA1")    
    metadata = {
        "result": envelope.get("result"),
        "url": envelope.get("url"),
        "previousBuild": envelope.get("previousBuild"),
        "mainCommit": main_commit

    }
    msg = envelope.get("fullDisplayName")
    signature = create_unique_id(msg)
    build_event = {
        "event_type": 'build',
        "id": e_id,
        "metadata": json.dumps(metadata),
        "time_created": time_created,
        "signature": signature,
        "msg_id": msg_id,
        "source": source,
    }  


    # Publish to Pub/Sub
   # publish_to_pubsub(source, body, headers)
    insert_row_into_bigquery(build_event)
    return build_event

def insert_row_into_bigquery(event):
    if not event:
        raise Exception("No data to insert")

    # Set up bigquery instance
    client = bigquery.Client()
    dataset_id = "four_keys"
    table_id = "events_raw"

    if is_unique(client, event["signature"]):
        table_ref = client.dataset(dataset_id).table(table_id)
        table = client.get_table(table_ref)

        # Insert row
        row_to_insert = [
            (
                event["event_type"],
                event["id"],
                event["metadata"],
                event["time_created"],
                event["signature"],
                event["msg_id"],
                event["source"],
            )
        ]
        bq_errors = client.insert_rows(table, row_to_insert)

        # If errors, log to Stackdriver
        if bq_errors:
            entry = {
                "severity": "WARNING",
                "msg": "Row not inserted.",
                "errors": bq_errors,
                "row": row_to_insert,
            }
            print(json.dumps(entry))

def show_the_login_form():
    return 'showing login form'

def create_unique_id(msg):
    hashed = hashlib.sha1(bytes(json.dumps(msg), "utf-8"))
    return hashed.hexdigest()

def is_unique(client, signature):
    sql = "SELECT signature FROM four_keys.events_raw WHERE signature = '%s'"
    query_job = client.query(sql % signature)
    results = query_job.result()
    return not results.total_rows

@app.route('/', methods=['POST'])
def index():
    return process_jenkins_event(request)  

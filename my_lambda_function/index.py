import os

import pandas
import requests

URI = os.getenv('URI', 'https://jsonplaceholder.typicode.com/todos')


def handler(event, context):
    resp = requests.get(URI).json()
    frame = pandas.DataFrame(resp)
    counts = frame.groupby('completed')['id'].count()
    return {'CompletedCount': counts.to_dict()}

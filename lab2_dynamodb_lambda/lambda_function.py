import json
import boto3
import time

# Initialize DynamoDB resource outside the handler for connection reuse
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("Lab2Items")


def lambda_handler(event, context):
    # Generate a unique ID using current Unix timestamp
    item = {
        "id": str(int(time.time())),
        "message": event.get("message", "HELLO FROM LAMBDA")
    }
    # Write item to DynamoDB
    table.put_item(Item=item)

    return {
        "statusCode": 200,
        "body": json.dumps("ITEM WRITTEN IN DYNAMODB")
    }

import boto3
import json
from dotenv import load_dotenv
import os

# Load environment variables
load_dotenv()

def s3_to_dynamo():
    # Load configuration from .env
    bucket_name = os.getenv("S3_BUCKET_NAME")
    table_name = os.getenv("DYNAMODB_TABLE_NAME")
    region = os.getenv("AWS_REGION")
    aws_access_key_id = os.getenv("AWS_ACCESS_KEY_ID")
    aws_secret_access_key = os.getenv("AWS_SECRET_ACCESS_KEY")
    aws_session_token = os.getenv("AWS_SESSION_TOKEN")

    try:
        # Initialize S3 client
        s3 = boto3.client(
            's3',
            aws_access_key_id=aws_access_key_id,
            aws_secret_access_key=aws_secret_access_key,
            aws_session_token=aws_session_token,
            region_name=region
        )
        
        # Initialize DynamoDB client
        dynamodb = boto3.resource(
            'dynamodb',
            aws_access_key_id=aws_access_key_id,
            aws_secret_access_key=aws_secret_access_key,
            aws_session_token=aws_session_token,
            region_name=region
        )
        
        # Get the DynamoDB table
        table = dynamodb.Table(table_name)

        # List objects in S3 bucket
        response = s3.list_objects_v2(Bucket=bucket_name)
        if 'Contents' not in response:
            print(f"No files found in bucket: {bucket_name}")
            return

        # Process each file
        for obj in response['Contents']:
            file_key = obj['Key']
            print(f"Processing file: {file_key}")
            
            # Get the file content
            file_content = s3.get_object(Bucket=bucket_name, Key=file_key)['Body'].read().decode('utf-8')
            data = json.loads(file_content)

            # Write each record to DynamoDB
            for record in data:
                table.put_item(Item=record)
            
            print(f"Data from {file_key} successfully uploaded to DynamoDB table: {table_name}")

    except Exception as e:
        print(f"An error occurred: {e}")



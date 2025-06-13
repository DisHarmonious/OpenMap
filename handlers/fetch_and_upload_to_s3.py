import json
from datetime import datetime
import boto3
import requests
from dotenv import load_dotenv
import os

# Load environment variables
load_dotenv()

def fetch_and_upload_to_s3():
    # Load config from .env
    bucket_name = os.getenv("S3_BUCKET_NAME")
    region = os.getenv("AWS_REGION")
    aws_access_key_id = os.getenv("AWS_ACCESS_KEY_ID")
    aws_secret_access_key = os.getenv("AWS_SECRET_ACCESS_KEY")
    aws_session_token = os.getenv("AWS_SESSION_TOKEN")
    api_key = os.getenv("OPENCHARGEMAP_API_KEY")
    
    logging.info(f"Function for api to s3 started")

    url = f"https://api.openchargemap.io/v3/poi/?output=json&countrycode=US&maxresults=1000&key={api_key}"

    try:
        # Fetch data
        response = requests.get(url)
        response.raise_for_status()
        data = response.json()

        # Serialize data to JSON
        json_data = json.dumps(data, indent=4)

        # Upload to S3
        s3 = boto3.client(
            's3',
            aws_access_key_id=aws_access_key_id,
            aws_secret_access_key=aws_secret_access_key,
            aws_session_token=aws_session_token,
            region_name=region
        )

        file_name = f"openchargemap_{datetime.utcnow().strftime('%Y-%m-%dT%H-%M-%S')}.json"
        s3.put_object(
            Bucket=bucket_name,
            Key=file_name,
            Body=json_data,
            ContentType='application/json'
        )

        print(f"Data uploaded to s3://{bucket_name}/{file_name}")
    except Exception as e:
        print(f"An error occurred: {e}")

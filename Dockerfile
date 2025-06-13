FROM python:3.9-slim

WORKDIR /app

COPY . .

RUN pip install boto3 requests python-dotenv

CMD ["bash", "-c", "python handlers/fetch_to_s3.py && python handlers/s3_to_dynamo.py"]

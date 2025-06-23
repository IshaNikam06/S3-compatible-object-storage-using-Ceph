#!/usr/bin/env python3

import boto3
from botocore.exceptions import ClientError
import sys

# S3 Configuration
endpoint_url = 'http://localhost:8080'
access_key = 'accesskey123'
secret_key = 'secretkey123'
bucket_name = 'test-bucket'

def test_s3_functionality():
    """Test basic S3 operations"""
    try:
        # Create S3 client
        s3 = boto3.client(
            's3',
            endpoint_url=endpoint_url,
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            region_name='us-east-1'
        )

        print("Testing S3 connectivity...")
        
        # Test 1: List buckets
        print("1. Listing buckets...")
        response = s3.list_buckets()
        print(f"   Found {len(response['Buckets'])} buckets")

        # Test 2: Create bucket
        print("2. Creating test bucket...")
        try:
            s3.create_bucket(Bucket=bucket_name)
            print(f"   Bucket '{bucket_name}' created successfully")
        except ClientError as e:
            if e.response['Error']['Code'] == 'BucketAlreadyOwnedByYou':
                print(f"   Bucket '{bucket_name}' already exists")
            else:
                raise

        # Test 3: Upload object
        print("3. Uploading test object...")
        test_content = "Hello from Ceph S3!"
        s3.put_object(
            Bucket=bucket_name,
            Key='test-file.txt',
            Body=test_content
        )
        print("   Object uploaded successfully")

        # Test 4: Download object
        print("4. Downloading test object...")
        response = s3.get_object(Bucket=bucket_name, Key='test-file.txt')
        downloaded_content = response['Body'].read().decode('utf-8')
        print(f"   Downloaded content: '{downloaded_content}'")

        # Test 5: List objects
        print("5. Listing objects in bucket...")
        response = s3.list_objects_v2(Bucket=bucket_name)
        if 'Contents' in response:
            print(f"   Found {len(response['Contents'])} objects")
            for obj in response['Contents']:
                print(f"   - {obj['Key']} ({obj['Size']} bytes)")

        # Verify content matches
        if downloaded_content == test_content:
            print("\nS3 functionality test PASSED!")
            print(f"Ceph RGW S3 API is working correctly")
            print(f"Endpoint: {endpoint_url}")
            return True
        else:
            print("\nContent mismatch!")
            return False

    except Exception as e:
        print(f"\nS3 test FAILED: {e}")
        return False

if __name__ == "__main__":
    success = test_s3_functionality()
    sys.exit(0 if success else 1)
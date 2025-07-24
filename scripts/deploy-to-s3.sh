#!/bin/bash

# Check if required environment variables are set
if [ -z "$AWS_S3_BUCKET" ]; then
    echo "Error: AWS_S3_BUCKET environment variable is not set"
    exit 1
fi

# Get the current timestamp for versioning
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BUILD_PATH="dist/login-app"

# Upload the new version to a timestamped directory
aws s3 cp $BUILD_PATH/ s3://$AWS_S3_BUCKET/$TIMESTAMP/ --recursive
UPLOAD_STATUS=$?

# Check if the upload was successful
if [ $UPLOAD_STATUS -eq 0 ]; then
    # Update the latest version
    aws s3 cp $BUILD_PATH/ s3://$AWS_S3_BUCKET/ --recursive
    echo "Successfully deployed version $TIMESTAMP"
else
    echo "Upload failed with status code: $UPLOAD_STATUS"
    # Get the previous version
    PREVIOUS_VERSION=$(aws s3 ls s3://$AWS_S3_BUCKET/ | grep -v index.html | sort | tail -n 1 | awk '{print $2}' | sed 's/\///')
    if [ ! -z "$PREVIOUS_VERSION" ]; then
        # Rollback to the previous version
        aws s3 cp s3://$AWS_S3_BUCKET/$PREVIOUS_VERSION/ s3://$AWS_S3_BUCKET/ --recursive
        echo "Deployment failed, rolled back to version $PREVIOUS_VERSION"
        exit 1
    else
        echo "Deployment failed and no previous version found for rollback"
        exit 1
    fi
fi

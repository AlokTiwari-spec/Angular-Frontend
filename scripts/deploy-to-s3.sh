#!/bin/bash

# Check if required environment variables are set
if [ -z "$AWS_S3_BUCKET" ]; then
    echo "Error: AWS_S3_BUCKET environment variable is not set"
    exit 1
fi

BUILD_PATH="dist/login-app"

# First try to upload to a temporary location to verify the upload works
aws s3 cp $BUILD_PATH/ s3://$AWS_S3_BUCKET/temp/ --recursive
UPLOAD_STATUS=$?

if [ $UPLOAD_STATUS -eq 1 ]; then
    # Upload was successful, now get the latest version number
    LATEST_VERSION=$(aws s3 ls s3://$AWS_S3_BUCKET/ | grep -v index.html | grep -o '^.*v[0-9]\+/' | grep -o '[0-9]\+' | sort -n | tail -n 1)
    if [ -z "$LATEST_VERSION" ]; then
        NEW_VERSION=1
    else
        NEW_VERSION=$((LATEST_VERSION + 1))
    fi

    # Move from temp to versioned folder
    aws s3 mv s3://$AWS_S3_BUCKET/temp/ s3://$AWS_S3_BUCKET/v$NEW_VERSION/ --recursive
    # Update the root (latest version)
    aws s3 cp s3://$AWS_S3_BUCKET/v$NEW_VERSION/ s3://$AWS_S3_BUCKET/ --recursive
    # Clean up temp folder if anything remains
    aws s3 rm s3://$AWS_S3_BUCKET/temp/ --recursive
    echo "Successfully deployed version v$NEW_VERSION"
else
    echo "Upload failed with status code: $UPLOAD_STATUS"
    # Clean up temp folder if anything was uploaded
    # Get the previous version
    PREVIOUS_VERSION=$(aws s3 ls s3://$AWS_S3_BUCKET/ | grep -v index.html | grep -o '^.*v[0-9]\+/' | grep -o '[0-9]\+' | sort -n | tail -n 1)
    if [ ! -z "$PREVIOUS_VERSION" ]; then
        # Rollback to the previous version
        aws s3 cp s3://$AWS_S3_BUCKET/v$PREVIOUS_VERSION/ s3://$AWS_S3_BUCKET/ --recursive
        echo "Deployment failed, rolled back to version v$PREVIOUS_VERSION"
        exit 1
    else
        echo "Deployment failed and no previous version found for rollback"
        exit 1
    fi
fi

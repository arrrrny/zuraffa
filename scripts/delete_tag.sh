#!/bin/bash

# Script to delete local and remote Git tags by version number
# Usage: ./delete_tag.sh <version_number>
# Example: ./delete_tag.sh 3.0.7

# Check if version number is provided
if [ $# -eq 0 ]; then
    echo "Error: No version number provided."
    echo "Usage: $0 <version_number>"
    echo "Example: $0 3.0.7"
    exit 1
fi

VERSION=$1
TAG_NAME="v$VERSION"

# Check if the tag exists locally
if git tag -l | grep -q "^${TAG_NAME}$"; then
    echo "Deleting local tag: $TAG_NAME"
    git tag -d "$TAG_NAME"
    if [ $? -eq 0 ]; then
        echo "Successfully deleted local tag: $TAG_NAME"
    else
        echo "Failed to delete local tag: $TAG_NAME"
        exit 1
    fi
else
    echo "Local tag $TAG_NAME does not exist."
fi

# Delete the remote tag
echo "Deleting remote tag: $TAG_NAME"
git push origin ":refs/tags/$TAG_NAME"

if [ $? -eq 0 ]; then
    echo "Successfully deleted remote tag: $TAG_NAME"
elif [ $? -eq 1 ]; then
    # git push returns 1 when trying to delete non-existent remote tag, but this is not necessarily an error
    echo "Remote tag $TAG_NAME may not have existed or deletion was rejected."
else
    echo "Failed to delete remote tag: $TAG_NAME"
    exit 1
fi

echo "Tag deletion process completed for: $TAG_NAME"

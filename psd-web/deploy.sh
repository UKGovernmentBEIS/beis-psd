#!/usr/bin/env bash
set -ex

# Set the manifest file
MANIFEST_FILE=./psd-web/manifest.yml

# Copy the environment helper script
cp -a ./infrastructure/env/. ./psd-web/env/

# Deploy the app
cf7 push -f $MANIFEST_FILE $APP_NAME --var psd-host=$DOMAIN --var memory=$MEMORY --var web-instances=$WEB_INSTANCES --var worker-instances=$WORKER_INSTANCES --strategy rolling

# Remove the copied infrastructure env files to clean up
rm -R cosmetics-web/env/

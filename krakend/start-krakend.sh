#!/bin/sh
ENV=${KRAKEND_ENVIRONMENT:-multi-env}
CONFIG_FILE="/etc/krakend/environments/${ENV}/krakend.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Configuration file $CONFIG_FILE not found"
  echo "Available environments:"
  ls /etc/krakend/environments/
  exit 1
fi

echo "Starting KrakenD with environment: $ENV"
echo "Configuration file: $CONFIG_FILE"

# Replace backend URLs if environment variables are provided
TEMP_CONFIG="/tmp/krakend.json"
cp "$CONFIG_FILE" "$TEMP_CONFIG"

# Replace development backend URL (chatwoot-test)
if [ -n "$KRAKEND_DEV_BACKEND_URL" ]; then
  echo "Updating development backend URL to: $KRAKEND_DEV_BACKEND_URL"
  sed -i "s|https://chatwoot-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io|$KRAKEND_DEV_BACKEND_URL|g" "$TEMP_CONFIG"
fi

# Replace staging backend URL
if [ -n "$KRAKEND_STAGING_BACKEND_URL" ]; then
  echo "Updating staging backend URL to: $KRAKEND_STAGING_BACKEND_URL"
  sed -i "s|https://chatwoot-staging.calmmushroom-30b1c815.eastus.azurecontainerapps.io|$KRAKEND_STAGING_BACKEND_URL|g" "$TEMP_CONFIG"
fi

# Replace production backend URL
if [ -n "$KRAKEND_PROD_BACKEND_URL" ]; then
  echo "Updating production backend URL to: $KRAKEND_PROD_BACKEND_URL"
  sed -i "s|https://chatwoot-production.calmmushroom-30b1c815.eastus.azurecontainerapps.io|$KRAKEND_PROD_BACKEND_URL|g" "$TEMP_CONFIG"
fi

# Legacy support for single backend URL (applies to development now)
if [ -n "$KRAKEND_BACKEND_URL" ]; then
  echo "Updating backend URL to: $KRAKEND_BACKEND_URL"
  sed -i "s|https://chatwoot-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io|$KRAKEND_BACKEND_URL|g" "$TEMP_CONFIG"
fi

exec /usr/bin/krakend run -c "$TEMP_CONFIG" 
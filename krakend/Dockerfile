FROM krakend/krakend-ce:2.4

# Copy all environment configurations
COPY environments/ /etc/krakend/environments/

# Create a script to select the right configuration based on environment
RUN echo '#!/bin/sh\n\
ENV=${KRAKEND_ENVIRONMENT:-test}\n\
CONFIG_FILE="/etc/krakend/environments/${ENV}/krakend.json"\n\
\n\
if [ ! -f "$CONFIG_FILE" ]; then\n\
  echo "Error: Configuration file $CONFIG_FILE not found"\n\
  echo "Available environments:"\n\
  ls /etc/krakend/environments/\n\
  exit 1\n\
fi\n\
\n\
echo "Starting KrakenD with environment: $ENV"\n\
echo "Configuration file: $CONFIG_FILE"\n\
\n\
# Replace backend URLs if KRAKEND_BACKEND_URL is provided\n\
if [ -n "$KRAKEND_BACKEND_URL" ]; then\n\
  echo "Updating backend URL to: $KRAKEND_BACKEND_URL"\n\
  sed "s|https://chatwoot-working.calmmushroom-30b1c815.eastus.azurecontainerapps.io|$KRAKEND_BACKEND_URL|g" "$CONFIG_FILE" > /tmp/krakend.json\n\
  CONFIG_FILE="/tmp/krakend.json"\n\
fi\n\
\n\
exec /usr/bin/krakend run -c "$CONFIG_FILE"' > /usr/local/bin/start-krakend.sh

RUN chmod +x /usr/local/bin/start-krakend.sh

# Set default environment
ENV KRAKEND_ENVIRONMENT=test

# Use our startup script
CMD ["/usr/local/bin/start-krakend.sh"] 
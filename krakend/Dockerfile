FROM --platform=linux/amd64 devopsfaith/krakend:2.6

# Copy all environment configurations
COPY environments/ /etc/krakend/environments/

# Copy the startup script
COPY start-krakend.sh /start-krakend.sh
RUN chmod +x /start-krakend.sh

# Set default environment
ENV KRAKEND_ENVIRONMENT=test

# Use our startup script as entrypoint
ENTRYPOINT ["/start-krakend.sh"] 
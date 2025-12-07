FROM python:3.13.5-alpine

WORKDIR /app

# Copy all the files under backend
COPY . ./

# Install dependencies and upgrade system packages
# First, update package lists and install initial tools.
# Then, upgrade all installed packages to their latest versions to address vulnerabilities.
# Clean up apk cache to reduce image size.
RUN apk add --update jq curl py-pip inotify-tools \
    && apk upgrade \
    && rm -rf /var/cache/apk/* \
    && pip install --no-cache-dir -r requirements.txt

# Expose the WebSocket port
EXPOSE 80

ENV LOGLEVEL=INFO

ENV MCP_PORT=8000

RUN chmod +x entrypoint.sh
ENTRYPOINT ["./entrypoint.sh"]

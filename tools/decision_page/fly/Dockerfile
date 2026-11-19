FROM python:3.13-alpine
RUN apk add --no-cache su-exec
COPY site/ /app/
ENV DECISION_ROOT=/app DECISION_HOST=0.0.0.0 DECISION_PORT=8080
# Fly mounts the volume root-owned: hand it to nobody, then drop root before serving.
CMD ["sh", "-c", "chown 65534:65534 /data && exec su-exec 65534:65534 python3 -u /app/tools/decision_page/server.py"]

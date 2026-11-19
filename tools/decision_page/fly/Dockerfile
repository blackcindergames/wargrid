FROM python:3.13-alpine
COPY site/ /app/
COPY flyserve.py /app/flyserve.py
RUN chown -R 65534:65534 /app/docs/images/hud-v5/source
USER 65534:65534
CMD ["python3", "-u", "/app/flyserve.py"]

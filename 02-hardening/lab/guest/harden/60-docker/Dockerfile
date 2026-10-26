# Containment step: same buggy app, but boxed in. The injection still "works";
# it just lands in a throwaway, unprivileged, read-only container instead of on
# the host as root.
#
# Build during provisioning while egress is open, before Act-2 nftables.
# Include ping so the legitimate /api/ping feature remains available.
FROM python:3.12-slim-bookworm

# Use unprivileged ICMP sockets; file capabilities conflict with cap-drop ALL.
RUN apt-get update \
    && apt-get install -y --no-install-recommends iputils-ping \
    && setcap -r /usr/bin/ping \
    && rm -rf /var/lib/apt/lists/*

# A non-root service account. The container never runs as uid 0.
RUN useradd --system --no-create-home --uid 10001 pingboard

WORKDIR /app
COPY app/pingboard.py /app/pingboard.py

USER pingboard
EXPOSE 8080
ENV PINGBOARD_LOG_DIR=/var/log/pingboard
CMD ["python3", "-u", "/app/pingboard.py"]

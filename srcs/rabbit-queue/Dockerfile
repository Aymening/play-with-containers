FROM debian:12-slim

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        rabbitmq-server \
        curl \
        ca-certificates \
    && rabbitmq-plugins enable --offline rabbitmq_management \
    && rm -rf /var/lib/apt/lists/*

ENV HOME=/var/lib/rabbitmq
ENV RABBITMQ_MNESIA_BASE=/var/lib/rabbitmq/mnesia
ENV RABBITMQ_NODENAME=rabbit@rabbit-queue

COPY --chmod=755 srcs/rabbit-queue/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY srcs/rabbit-queue/rabbitmq.conf /etc/rabbitmq/rabbitmq.conf

EXPOSE 5672
VOLUME ["/var/lib/rabbitmq"]
STOPSIGNAL SIGTERM

HEALTHCHECK --interval=5s --timeout=10s --start-period=30s --retries=12 \
    CMD runuser -u rabbitmq -- rabbitmq-diagnostics -q ping || exit 1

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["rabbitmq-server"]

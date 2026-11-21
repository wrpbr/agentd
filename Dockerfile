# syntax=docker/dockerfile:1
# Public distribution Dockerfile for agentd (https://github.com/wrpbr/agentd)
# Layers local rules and configuration on top of the prebuilt wrpbr/agentd image.

FROM wrpbr/agentd:0.1.0

COPY config.env /usr/local/lib/agentd/config.env
COPY rules/core/*.json /usr/local/share/agentd/rules/core/
COPY rules/catalogs/*.json /usr/local/share/agentd/rules/catalogs/
COPY docker/entrypoint.sh /usr/local/bin/agentd-entrypoint
RUN chmod 0755 /usr/local/bin/agentd-entrypoint

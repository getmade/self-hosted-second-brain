FROM alpine/git:latest
COPY sync.sh /usr/local/bin/sync.sh
RUN chmod +x /usr/local/bin/sync.sh && mkdir -p /vault && chown 1000:1000 /vault
# Same user ID as the Basic Memory container, so both can write to the vault.
USER 1000:1000
ENV HOME=/tmp
WORKDIR /vault
ENTRYPOINT ["/usr/local/bin/sync.sh"]

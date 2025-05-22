FROM postgres:16.3

# Create a log file and give ownership to postgres
RUN touch /startup_log.txt
RUN chown postgres:postgres /startup_log.txt

# Inject an echo right before exec "$@" in docker-entrypoint.sh
RUN sed -i -E 's,^(.*)(exec "\$@"),\1echo "STARTING_UP" > /startup_log.txt\n\1\2,' /usr/local/bin/docker-entrypoint.sh
ARG DB2_VERSION=11.5.9.0

FROM icr.io/db2_community/db2:${DB2_VERSION}

RUN mkdir /var/custom && \
    touch /startup_log.txt && \
    sed -i -E 's,(^.*)(while :),\1echo "STARTING_UP" > /startup_log.txt\n\1\2,' /var/db2_setup/lib/setup_db2_instance.sh

COPY --chmod=a+x conf/* /var/custom
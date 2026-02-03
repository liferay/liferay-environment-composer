ARG DB2_VERSION=11.5.9.0

FROM icr.io/db2_community/db2:${DB2_VERSION}

RUN mkdir /var/custom

COPY --chmod=a+x conf/* /var/custom
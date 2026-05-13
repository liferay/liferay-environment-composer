ARG ELASTICSEARCH_VERSION

FROM elasticsearch:${ELASTICSEARCH_VERSION}

ARG ELASTICSEARCH_VERSION

RUN if [ "${ELASTICSEARCH_VERSION%%.*}" = "7" ]; then echo -e "xpack.monitoring.enabled: false\nxpack.sql.enabled: false" >> /usr/share/elasticsearch/config/elasticsearch.yml; fi
RUN /usr/share/elasticsearch/bin/elasticsearch-plugin install\
    analysis-icu\
    analysis-kuromoji\
    analysis-smartcn\
    analysis-stempel
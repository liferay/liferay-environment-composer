FROM debian:trixie-backports

RUN apt-get update && \
    apt-get -y install \
        -t trixie-backports libreoffice-nogui \
        netcat-traditional

EXPOSE 8100

CMD ["/usr/bin/soffice", "--headless", "--nologo", "--nofirststartwizard", "--accept=socket,host=0.0.0.0,port=8100;urp"]
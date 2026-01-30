FROM debian:13.2-slim

RUN echo "deb http://deb.debian.org/debian/ trixie-backports main contrib" > /etc/apt/sources.list.d/backports.list && \
    apt-get update && \
    apt-get -y install \
        -t trixie-backports libreoffice-nogui \
        netcat-traditional

EXPOSE 8100

CMD ["/usr/bin/soffice", "--headless", "--nologo", "--nofirststartwizard", "--accept=socket,host=0.0.0.0,port=8100;urp"]
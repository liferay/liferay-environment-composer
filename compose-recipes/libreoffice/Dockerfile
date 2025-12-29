FROM debian:13.2-slim

RUN apt-get update && \
    apt-get -y install libreoffice-nogui netcat-traditional

EXPOSE 8100

CMD ["/usr/bin/libreoffice", "--headless", "--nologo", "--nofirststartwizard", "--accept=socket,host=0.0.0.0,port=8100;urp"]
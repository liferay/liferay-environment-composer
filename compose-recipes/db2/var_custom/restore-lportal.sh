echo "lportal" | su db2admin <<EOSU
. /database/config/db2admin/sqllib/db2profile
[ "$(ls /database/data/db2admin/NODE0000/lportal/backup)" ] && \
    db2 connect to lportal && \
    db2 force application all && \
    db2 terminate && \
    db2stop force && \
    ipclean -a && \
    db2set -null DB2COMM && \
    db2start admin mode restricted access && \
    db2 RESTORE DATABASE lportal FROM /database/data/db2admin/NODE0000/lportal/backup INTO lportal REPLACE EXISTING WITHOUT ROLLING FORWARD && \
    db2stop force && \
    ipclean -a && \
    db2set DB2COMM=TCPIP && \
    db2start && \
    db2 activate db lportal && \
    db2 connect to lportal || echo
EOSU
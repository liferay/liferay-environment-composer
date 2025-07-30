echo "lportal" | su db2admin <<EOSU
/opt/ibm/db2/V11.5/bin/db2 create db lportal pagesize 32768 temporary tablespace managed by automatic storage
EOSU
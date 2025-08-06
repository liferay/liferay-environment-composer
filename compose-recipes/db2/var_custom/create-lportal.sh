echo "lportal" | su db2admin <<EOSU
. /database/config/db2admin/sqllib/db2profile
db2 create db lportal pagesize 32768 temporary tablespace managed by automatic storage
EOSU
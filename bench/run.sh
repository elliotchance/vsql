#rm -f bench/pgbench.vsql
#v run cmd/vsql.v server -v bench/pgbench.vsql
#PID=$!
#sleep 5

# psql -p 3210 -h 127.0.0.1 -c 'SELECT * FROM singlerow'
pgbench -p 3210 -h 127.0.0.1 -b select-only
#kill $PID

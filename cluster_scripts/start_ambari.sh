#!/bin/bash

echo "start_ambari: Waiting for Ambari server to come up"
while true
do
  curl "http://master-1:8080" >&/dev/null && break
done

echo "Starting Ambari agent"
ambari-agent start
echo "start_ambari: done"


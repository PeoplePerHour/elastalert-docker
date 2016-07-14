#!/bin/sh

set -e

# Check if we need to download the rules from s3.
d=$(ls -A /opt/rules)
if [ -z "$d" ];
then
    echo "Empty rules fetching from s3";
    aws s3 sync s3://$S3_BUCKET/ /opt/rules
    for i in `ls /opt/rules/`;
    do
      echo "moving $i";
      newname="/opt/rules/$i.tpl"
      mv /opt/rules/$i $newname
      envsubst < $newname > /opt/rules/$i
    done
else
    echo "Local mode with mounded rules";
fi

# Wait until Elasticsearch is online since otherwise Elastalert will fail.
rm -f garbage_file
while ! wget -O garbage_file ${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT} 2>/dev/null
do
	echo "Waiting for ${ELASTICSEARCH_HOST} Elasticsearch..."
	rm -f garbage_file
	sleep 1
done
rm -f garbage_file
sleep 1

# Check if the Elastalert index exists in Elasticsearch and create it if it does not.
if ! wget -O garbage_file ${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}/elastalert_status 2>/dev/null
then
  echo "Creating Elastalert ${ELASTICSEARCH_HOST} index in Elasticsearch..."
	elastalert-create-index  --host $ELASTICSEARCH_HOST \
	                          --port $ELASTICSEARCH_PORT \
                            --no-auth \
                            --no-ssl \
                            --url-prefix "" \
                            --index elastalert_status \
                            --old-index ""
else
    echo "Elastalert index already exists in Elasticsearch."
fi
rm -f garbage_file
mv /opt/config/config.yaml /opt/config/config.tpl.yaml
envsubst < /opt/config/config.tpl.yaml > /opt/config/config.yaml

echo "Starting Elastalert..."
exec supervisord -c ${ELASTALERT_SUPERVISOR_CONF} -n
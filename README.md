## peopleperhour/elastalert ##

Docker image for the elasticalert by YELP with Alpine base image

More information regarding how to write rules http://elastalert.readthedocs.org/en/latest/recipes/writing_filters.html
and some example rules https://github.com/Yelp/elastalert/tree/master/example_rules

This container will check if there is data inside the /opt/rules directory and if not then it will download the rules from s3 bucket.

The name of the bucket as well as the credentials to access the bucket (IAM user) are passed as env vars (see bellow Environment Variables)

The container is based on the https://hub.docker.com/r/ivankrizsan/elastalert/ docker container with addition of s3 download rules.

### Build

```
make
```

### Local Testing
You have to first build the container with `make`

```
docker run --rm -it -v $(pwd)/:/opt/rules  \
        -e ELASTICSEARCH_HOST=192.168.66.6 \
        peopleperhour/elastalert bash;

$ mv /opt/config/config.yaml /opt/config/config.tpl.yaml
$ envsubst < /opt/config/config.tpl.yaml > /opt/config/config.yaml
```
You can now run the elastalert-test-rule to validate your rules
```
bash-4.3# elastalert-test-rule --help
usage: elastalert-test-rule [-h] [--schema-only] [--days DAYS]
                            [--data FILENAME] [--alert] [--save-json FILENAME]
                            [--count-only] [--config CONFIG]
                            rule

Validate a rule configuration

positional arguments:
  rule                  rule configuration filename

optional arguments:
  -h, --help            show this help message and exit
  --schema-only         Show only schema errors; do not run query
  --days DAYS           Query the previous N days with this rule
  --data FILENAME       A JSON file containing data to run the rule against
  --alert               Use actual alerts instead of debug output
  --save-json FILENAME  A file to which documents from the last day or --days
                        will be saved
  --count-only          Only display the number of documents matching the
                        filter
  --config CONFIG       Global config file.
```
Example:
```
bash-4.3# elastalert-test-rule \
  --config /opt/config/config.yaml \
  --days 1 \
  example_rule.yaml;
```
### Environment Variables
- ELASTICSEARCH_HOST: the elasticsearch host
- S3_BUCKET: the bucket that holds the rules
- AWS_ACCESS_KEY_ID : The IAM key
- AWS_SECRET_ACCESS_KEY : The IAM secrete
- AWS_DEFAULT_REGION: The region where the bucket is.

# Volumes
/opt/logs       - Elastalert and Supervisord logs will be written to this directory.<br/>
/opt/config     - Elastalert (elastalert_config.yaml) and Supervisord (elastalert_supervisord.conf) configuration files.<br/>
/opt/rules      - Contains Elastalert rules.<br/>

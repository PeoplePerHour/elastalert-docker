FROM alpine:3.3

# URL from which to download Elastalert.
ENV ELASTALERT_URL https://github.com/Yelp/elastalert/archive/master.zip

# Directory holding configuration for Elastalert and Supervisor.
ENV CONFIG_DIR /opt/config
# Elastalert rules directory.
ENV RULES_DIRECTORY /opt/rules
# Elastalert configuration file path in configuration directory.
ENV ELASTALERT_CONFIG ${CONFIG_DIR}/config.yaml
# Directory to which Elastalert and Supervisor logs are written.
ENV LOG_DIR /opt/logs
# Elastalert home directory name.
ENV ELASTALERT_DIRECTORY_NAME elastalert
# Elastalert home directory full path.
ENV ELASTALERT_HOME /opt/${ELASTALERT_DIRECTORY_NAME}
# Supervisor configuration file for Elastalert.
ENV ELASTALERT_SUPERVISOR_CONF ${CONFIG_DIR}/elastalert_supervisord.conf
# Alias, DNS or IP of Elasticsearch host to be queried by Elastalert. Set in default Elasticsearch configuration file.
ENV ELASTICSEARCH_HOST es_host
# Port on above Elasticsearch host. Set in default Elasticsearch configuration file.
ENV ELASTICSEARCH_PORT 9200

ENV S3_BUCKET=staging_elastalert_rules

RUN apk add --no-cache bash python python-dev gcc musl-dev openssl py-pip gettext&& \
    apk add --no-cache --virtual=build-dependencies wget ca-certificates && \
    wget "https://bootstrap.pypa.io/get-pip.py" -O /dev/stdout | python && \
    apk del build-dependencies

WORKDIR /opt

# Install AWS CLI
RUN pip install awscli

COPY ./config /opt/config
COPY ./start-elastalert.sh /opt/

RUN \
# Download and unpack Elastalert.
    wget ${ELASTALERT_URL} && \
    unzip *.zip && \
    rm *.zip &&\
    mv e* ${ELASTALERT_DIRECTORY_NAME}

WORKDIR ${ELASTALERT_HOME}

# Install Elastalert.
RUN python setup.py install && \
    pip install -e . && \

# Install Supervisor.
    easy_install supervisor && \

# Make the start-script executable.
    chmod +x /opt/start-elastalert.sh && \

# Create directories.
    mkdir -p ${CONFIG_DIR} && \
    mkdir -p ${RULES_DIRECTORY} && \
    mkdir -p ${LOG_DIR} && \

# Copy default configuration files to configuration directory.
    cp ${ELASTALERT_HOME}/supervisord.conf.example ${ELASTALERT_SUPERVISOR_CONF} && \


# Elastalert Supervisor configuration:
    # Redirect Supervisor log output to a file in the designated logs directory.
    sed -i -e"s|logfile=.*log|logfile=${LOG_DIR}/elastalert_supervisord.log|g" ${ELASTALERT_SUPERVISOR_CONF} && \
    # Redirect Supervisor stderr output to a file in the designated logs directory.
    sed -i -e"s|stderr_logfile=.*log|stderr_logfile=${LOG_DIR}/elastalert_stderr.log|g" ${ELASTALERT_SUPERVISOR_CONF} && \
    # Modify the start-command.
    sed -i -e"s|python elastalert.py|python -m elastalert.elastalert --config ${ELASTALERT_CONFIG}|g" ${ELASTALERT_SUPERVISOR_CONF} && \

# Clean up.
    apk del python-dev && \
    apk del musl-dev && \
    apk del gcc && \

# Add Elastalert to Supervisord.
    supervisord -c ${ELASTALERT_SUPERVISOR_CONF}

# Define mount points.
VOLUME [ "${CONFIG_DIR}", "${RULES_DIRECTORY}", "${LOG_DIR}"]

# Launch Elastalert when a container is started.
CMD ["/opt/start-elastalert.sh"]

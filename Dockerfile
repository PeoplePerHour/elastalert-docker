FROM python:2.7.13-alpine

# URL from which to download Elastalert.
ENV ELASTALERT_VERSION 0.1.6
ENV ELASTALERT_URL https://github.com/Yelp/elastalert/archive/v${ELASTALERT_VERSION}.tar.gz

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

# Python has a problem with SSL certificate verification
ENV PYTHONHTTPSVERIFY=0

WORKDIR ${ELASTALERT_HOME}

COPY ./config /opt/config
COPY ./start-elastalert.sh /opt/

RUN apk add --no-cache --virtual=build-dependencies \
      bash \
      gcc \
      musl-dev \
      openssl \
      gettext \
      wget \
      ca-certificates  \
      openssl-dev \
      libffi-dev \
      build-base &&\
      apk --update add tar &&\
    #wget "https://bootstrap.pypa.io/get-pip.py" -O /dev/stdout | python && \


# Download and unpack Elastalert.
    mkdir -p ${ELASTALERT_HOME} &&\
    cd ${ELASTALERT_HOME} &&\
    wget -O elastalert.tar.gz ${ELASTALERT_URL} &&\
    tar --strip-components=1  -xzf elastalert.tar.gz &&\
    rm elastalert.tar.gz &&\
    ls -la &&\

# Install AWS CLI, in order to download the rules from S3
    pip install awscli &&\

# Install Elastalert.
    python setup.py install && \
    pip install -e . && \
    pip uninstall twilio --yes && \
    pip install twilio==6.0.0 &&\

# Install Supervisor.
    pip install supervisor && \

# Make the start-script executable.
    chmod +x /opt/start-elastalert.sh && \

# Create directories.
    mkdir -p ${CONFIG_DIR} && \
    mkdir -p ${RULES_DIRECTORY} && \
    mkdir -p ${LOG_DIR} && \

# Copy default configuration files to configuration directory.
    cp supervisord.conf.example ${ELASTALERT_SUPERVISOR_CONF} && \


# Elastalert Supervisor configuration:
    # Redirect Supervisor log output to a file in the designated logs directory.
    sed -i -e"s|logfile=.*log|logfile=${LOG_DIR}/elastalert_supervisord.log|g" ${ELASTALERT_SUPERVISOR_CONF} && \
    # Redirect Supervisor stderr output to a file in the designated logs directory.
    sed -i -e"s|stderr_logfile=.*log|stderr_logfile=${LOG_DIR}/elastalert_stderr.log|g" ${ELASTALERT_SUPERVISOR_CONF} && \
    # Modify the start-command.
    sed -i -e"s|python elastalert.py|python -m elastalert.elastalert --config ${ELASTALERT_CONFIG}|g" ${ELASTALERT_SUPERVISOR_CONF} && \

# Add Elastalert to Supervisord.
    supervisord -c ${ELASTALERT_SUPERVISOR_CONF} &&\

# Clean up.
    apk del python-dev \
            musl-dev \
            gcc \
            py-setuptools \
            openssl-dev \
            libffi-dev \
            tar build-base && \

     rm -rf /var/cache/apk/*

# Define mount points.
VOLUME [ "${CONFIG_DIR}", "${RULES_DIRECTORY}", "${LOG_DIR}"]

# Launch Elastalert when a container is started.
CMD ["/opt/start-elastalert.sh"]

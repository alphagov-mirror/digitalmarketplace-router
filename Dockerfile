FROM nginx:1.14

ENV APP_DIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
                    python2.7 python-setuptools python-pip curl && \
    rm -rf /var/lib/apt/lists/* && \
    pip install --no-cache-dir supervisor==3.3.3 awscli awscli-cwlogs && \
    aws configure set plugins.cwlogs cwlogs && \
    mkdir -p ${APP_DIR} && \
    mkdir -p /etc/nginx/sites-available && \
    mkdir -p /etc/nginx/sites-enabled && \
    mkdir -p /usr/share/nginx/html && \
    mkdir -p /var/log/digitalmarketplace && \
    rm -f /etc/nginx/nginx.conf /etc/nginx/sites-enabled/*

# TODO prefer apt-get install if nginx-prometheus-exporter is ever packaged as such
# For now make do with binary tarball and assert its sha256
RUN curl -SL -o nginx-prometheus-exporter.tar.gz https://github.com/nginxinc/nginx-prometheus-exporter/releases/download/v0.3.0/nginx-prometheus-exporter-0.3.0-linux-amd64.tar.gz && \
    test $(sha256sum nginx-prometheus-exporter.tar.gz | cut -d " " -f 1) = 31de68284339041fc5539f3b5431276989bea3de3705d932e80cc9f89cc9b21a && \
    tar -zxf nginx-prometheus-exporter.tar.gz && \
    install nginx-prometheus-exporter /usr/local/bin/nginx-prometheus-exporter && \
    rm -f nginx-prometheus-exporter nginx-prometheus-exporter.tar.gz

COPY requirements.txt ${APP_DIR}
RUN pip install -r ${APP_DIR}/requirements.txt

COPY static_files/* /usr/share/nginx/html/

COPY awslogs/awslogs.conf /etc/awslogs.conf
COPY awslogs/run.sh /awslogs.sh

COPY supervisord.conf /etc/supervisord.conf

COPY nginx.sh /nginx.sh

COPY nginx-prometheus-exporter.sh /nginx-prometheus-exporter.sh

COPY templates/ ${APP_DIR}/templates/
COPY scripts/ ${APP_DIR}/scripts/

CMD ["supervisord", "--configuration", "/etc/supervisord.conf"]

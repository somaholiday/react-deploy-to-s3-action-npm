FROM node:20-alpine AS linux

RUN apk --no-cache add \ 
        bash \
        curl \
        less \
        groff \
        jq \
        git \
        python3 \
        py3-pip \
        py-pip && \
        pip install --break-system-packages --upgrade pip awscli s3cmd  && \
        mkdir /root/.aws

ENV PATH=/github/workspace/node_modules/.bin:$PATH
ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

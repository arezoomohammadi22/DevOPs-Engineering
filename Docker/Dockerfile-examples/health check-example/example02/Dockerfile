FROM docker.arvancloud.ir/nginx:latest
LABEL maintainer="sananet"
LABEL version="2.1"
COPY  --chown=10:11 test.txt /dir1/
ADD test02.txt /dir02/
ENV MYVAR="123"
COPY nginx-configs /etc/nginx/conf.d/
RUN mkdir /usr/share/nginx/devops.com/
COPY index.html /usr/share/nginx/devops.com/
HEALTHCHECK --interval=35s --timeout=4s CMD curl -f http://localhost:9000/health || exit 1

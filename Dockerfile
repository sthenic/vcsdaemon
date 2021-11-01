FROM nimlang/nim:alpine
RUN apk --no-cache add curl apr subversion-dev
RUN mkdir -p /app/src && mkdir /app/lib
WORKDIR /app
RUN nimble install -y jester libcurl
COPY help.txt /app
COPY src /app/src/
COPY lib /app/lib/
RUN nimble build -d:release
CMD ["sh", "-c", "/app/vcsdaemon --alasso-url=$ALASSO_URL --restart-on-error --restart-on-timeout"]

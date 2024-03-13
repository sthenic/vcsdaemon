FROM nimlang/nim:2.0.2-alpine
RUN apk --no-cache add curl apr subversion-dev libgit2-dev
RUN mkdir -p /app/src && mkdir /app/lib
WORKDIR /app
RUN nimble refresh
COPY help.txt /app
COPY vcsdaemon.nimble /app
COPY src /app/src/
COPY lib /app/lib/
RUN nimble build -d:release
CMD ["sh", "-c", "/app/vcsdaemon --alasso-url=$ALASSO_URL --restart-on-error --restart-on-timeout"]

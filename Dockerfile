FROM klakegg/hugo:0.101.0

COPY . /site
WORKDIR /site

RUN hugo --minify --buildFuture -v -b $HUGO_BASE_URL --appendPort=$HUGO_APPEND_PORT

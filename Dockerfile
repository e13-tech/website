FROM --platform=$BUILDPLATFORM debian:bookworm as builder

RUN apt-get update && apt-get -y install git make curl

WORKDIR /blog
COPY . .

RUN make hugo
RUN ./bin/hugo

FROM nginx:1.25.4-alpine

COPY --from=builder /blog/public /usr/share/nginx/html
COPY default.conf /etc/nginx/conf.d/

FROM golang:1-alpine AS build

WORKDIR /go/src/boilerplate
COPY . .
RUN set -x \
    && go get -d -v \
    && go build -v -o boilerplate

FROM alpine:3
WORKDIR /app
COPY --from=build /go/src/boilerplate/boilerplate .
EXPOSE 8080
CMD ["./boilerplate"]

# Build context is fly/ after sh sync.sh: site/src is the Go module, the rest of site/ is served from /app.
FROM --platform=$BUILDPLATFORM golang:1.27.4@sha256:5e8afd493a7124a8586e134d9b532731161d4b9becf9dee5a5956b107426f93d AS build
ARG TARGETOS TARGETARCH
WORKDIR /src
COPY site/src/go.mod site/src/go.sum ./
RUN go mod download
COPY site/src/ ./
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags=-s -o /warroom .

FROM alpine:3.22
RUN apk add --no-cache su-exec
COPY --from=build /warroom /usr/local/bin/warroom
COPY site/ /app/
RUN rm -rf /app/src
ENV WARROOM_ROOT=/app WARROOM_ROUNDS=/app/rounds WARROOM_HOST=0.0.0.0
# Fly mounts the volume root-owned: hand it to nobody, then drop root before serving.
CMD ["sh", "-c", "chown 65534:65534 /data && exec su-exec 65534:65534 warroom"]

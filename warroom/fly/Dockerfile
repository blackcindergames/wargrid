# Build context is fly/ after sh sync.sh: site/src is the Go module, the rest of site/ is served from /app.
FROM --platform=$BUILDPLATFORM golang:1.27.4@sha256:5e8afd493a7124a8586e134d9b532731161d4b9becf9dee5a5956b107426f93d AS build
ARG TARGETOS TARGETARCH
WORKDIR /src
COPY site/src/go.mod site/src/go.sum ./
RUN go mod download
COPY site/src/ ./
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags=-s -o /warroom .

FROM build AS assets
COPY site/ /app/
RUN rm -rf /app/src

# Root variant, resolved 2026-11-20: the binary hands the Fly volume to uid 65534 and drops root itself.
FROM gcr.io/distroless/static-debian12@sha256:d75cdd72874d4790092fcb1b058493ecf6bb5bf2b2b897045b00ff01d91843f2
COPY --from=build /warroom /warroom
COPY --from=assets /app /app
ENV WARROOM_ROOT=/app WARROOM_ROUNDS=/app/rounds WARROOM_HOST=0.0.0.0 WARROOM_RUN_AS=65534
EXPOSE 8780
ENTRYPOINT ["/warroom"]

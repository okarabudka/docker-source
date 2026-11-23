# syntax=docker/dockerfile:1

# Multi-stage build for a Go HTTP service: static binary on a distroless, non-root runtime.
#   docker build -f go/Dockerfile -t go-example go/example
FROM golang:1.27-alpine AS build

WORKDIR /src
ENV CGO_ENABLED=0

COPY go.mod go.sum* ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -trimpath -ldflags="-s -w" -o /out/app .

FROM gcr.io/distroless/static-debian13:nonroot

COPY --from=build /out/app /app

# 65532 is the "nonroot" user of distroless images
USER 65532:65532
EXPOSE 8080

# distroless has no shell or curl; the binary probes itself
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --start-interval=1s \
    CMD ["/app", "-healthcheck"]

ENTRYPOINT ["/app"]

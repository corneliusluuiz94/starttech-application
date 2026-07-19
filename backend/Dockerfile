# ---------- Build stage ----------
FROM golang:1.25.12-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o backend-api main.go

# ---------- Runtime stage ----------
FROM alpine:3.20

RUN apk add --no-cache ca-certificates && \
    adduser -D -u 1000 appuser

WORKDIR /app
COPY --from=builder /app/backend-api .

USER appuser
EXPOSE 8080

ENTRYPOINT ["./backend-api"]

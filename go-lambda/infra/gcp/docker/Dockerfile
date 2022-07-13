FROM golang:1.18-buster as builder
# Create and change to the app directory.
WORKDIR /app

# Retrieve application dependencies.
# This allows the container build to reuse cached dependencies.
# Expecting to copy go.mod and if present go.sum.
COPY cmd/go.* ./
RUN go mod download

# Copy local code to the container image.
COPY cmd/* ./

# Build the binary.
RUN GOOS=linux CGO_ENABLED=0 GOARCH=amd64 go build -o server

FROM debian:buster-slim

# Copy the binary to the production image from the builder stage.
COPY --from=builder /app/server /app/server

# Run the web service on container startup.
CMD ["/app/server"]

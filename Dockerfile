# Build stage
FROM debian:bookworm AS builder

# Install build tools
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the entire project context
COPY . .

# Build the project
RUN make clean
RUN make

# Run tests during the build
# If this fails, the 'docker build' command will stop immediately.
RUN make tset

# Runtime stage
FROM debian:bookworm-slim

# Run as a non-root user
RUN useradd -m -u 1000 -s /bin/bash dummyuser

WORKDIR /home/dummy

# Copy the built binary and LICENSE from the builder stage
COPY --from=builder /app/build/main ./dummydb
COPY --from=builder /app/LICENSE .

# Switch to the non-root user
USER dummyuser

# Define the command to run the app
CMD ["./dummydb"]
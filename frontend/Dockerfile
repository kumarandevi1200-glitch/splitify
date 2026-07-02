# Build stage
FROM debian:bookworm-slim AS build-env

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    && rm -rf /var/lib/apt/lists/*

# Clone Flutter SDK
RUN git clone https://github.com/flutter/flutter.git -b stable /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Initialize Flutter
RUN flutter doctor -v

# Set up project
WORKDIR /app
COPY . .

# Get packages and build web
RUN flutter pub get
RUN flutter build web --release

# Runtime stage
FROM nginx:alpine
COPY --from=build-env /app/build/web /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

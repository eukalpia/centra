FROM dart:stable AS build
WORKDIR /src
COPY pubspec.yaml pubspec.lock* ./
RUN dart pub get
COPY . .
RUN dart compile exe bin/centra.dart -o /out/centra

FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends openssh-client tar ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /out/centra /usr/local/bin/centra
ENTRYPOINT ["centra"]
CMD ["help"]

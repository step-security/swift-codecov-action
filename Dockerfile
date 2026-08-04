FROM mattpolzin2/swift-test-codecov:0.13.0@sha256:b8852ce22633be2821f868e9d4f3c78faeeba2d62a1f9a886c08d72a4f812670

RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends curl jq && rm -rf /var/lib/apt/lists/*

# WORKDIR /github/workspace

COPY swift_codecov.sh /usr/bin/swift_codecov.sh

ENTRYPOINT ["swift_codecov.sh"]

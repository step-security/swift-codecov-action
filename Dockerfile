FROM mattpolzin2/swift-test-codecov:0.13.0

RUN apt-get update && apt-get install -y --no-install-recommends curl jq && rm -rf /var/lib/apt/lists/*

# WORKDIR /github/workspace

COPY swift_codecov.sh /usr/bin/swift_codecov.sh

ENTRYPOINT ["swift_codecov.sh"]

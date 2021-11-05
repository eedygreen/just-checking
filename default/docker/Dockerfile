ARG JVMTAG=15.0.1

FROM azul/zulu-openjdk-debian:$JVMTAG

RUN apt-get update && apt-get -y install libatomic1 netcat wget \
    && groupadd -r bitso && useradd -r -m -g bitso bitso

ARG DATADOG_JAVA_AGENT_VERSION=0.75.0

WORKDIR /app

# Install the DataDog tracer agent
# https://docs.datadoghq.com/tracing/setup_overview/setup/java/?tab=containers
# Note: The docs suggest using the short URL https://dtdg.co/latest-java-tracer
# We don't use that URL for the following reasons:
# - It proved to be quite unreliable, causing build failures (see this PR for
#   more details https://github.com/bitsoex/bitso-exchange-java/pull/4223)
# - The short URL always gives the latest version, so for build repeatability, we
#   install a specific version
RUN wget --quiet --retry-connrefused --waitretry=1 --read-timeout=10 --timeout=10 --output-document /app/dd-java-agent.jar \
    https://repository.sonatype.org/service/local/repositories/central-proxy/content/com/datadoghq/dd-java-agent/${DATADOG_JAVA_AGENT_VERSION}/dd-java-agent-${DATADOG_JAVA_AGENT_VERSION}.jar && \
    chmod +x /app/dd-java-agent.jar && \
    chown -R bitso:bitso /app

USER bitso

COPY app/build/libs/default.jar /app/bitso-app.jar

CMD ["java", "-jar", "bitso-app.jar", "-Dorg.jooq.no-logo=true"]

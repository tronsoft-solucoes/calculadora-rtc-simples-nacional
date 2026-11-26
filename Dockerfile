# syntax=docker/dockerfile:1
# Offline API da calculadora do Simples Nacional.
# O banco SQLite oficial e gerado pela imagem do regime regular e copiado daqui.
# Nao faca docker build sozinho nesta pasta. Use o compose em ../calculadora-rtc,
# que declara o contexto adicional "regime_db" apontando para esse servico.

FROM regime_db AS database

FROM eclipse-temurin:25-jdk-noble AS build

WORKDIR /src

COPY .mvn .mvn
COPY mvnw pom.xml ./
COPY src src

RUN sed -i 's/\r$//' mvnw && chmod +x mvnw

RUN --mount=type=cache,target=/root/.m2 \
    ./mvnw -B -ntp -Dmaven.test.skip=true package

FROM eclipse-temurin:25-jre-noble

ENV TZ=America/Sao_Paulo \
    SPRING_PROFILES_ACTIVE=offline \
    JAVA_TOOL_OPTIONS="-XX:-UseBASE64Intrinsics -Duser.timezone=America/Sao_Paulo"

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends curl ca-certificates tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system --gid 10001 app \
    && useradd --system --uid 10001 --gid app --home-dir /app --shell /usr/sbin/nologin app

WORKDIR /app

COPY --from=build --chown=app:app /src/target/api-simples-nacional.jar /app/app.jar
COPY --from=database --chown=app:app /app/calculadora/db/calculadora-pro.db /app/calculadora/db/calculadora-pro.db

USER app

EXPOSE 8082 9103

HEALTHCHECK --interval=15s --timeout=5s --start-period=120s --retries=8 \
    CMD curl -fsS http://127.0.0.1:9103/health || exit 1

ENTRYPOINT ["java", "-jar", "/app/app.jar"]

ARG BASE_IMAGE=mcr.microsoft.com/dotnet/aspnet:10.0
FROM ${BASE_IMAGE}

ARG UPSTREAM_SHA
ARG UPSTREAM_REF
ARG SELF_CONTAINED=false
LABEL org.opencontainers.image.source="https://github.com/OrchardCMS/OrchardCore" \
      org.opencontainers.image.revision="${UPSTREAM_SHA}" \
      org.opencontainers.image.version="${UPSTREAM_REF}" \
      org.opencontainers.image.title="orchardcore-cms" \
      io.lab.self-contained="${SELF_CONTAINED}"

ENV ASPNETCORE_URLS=http://+:8080 \
    DOTNET_RUNNING_IN_CONTAINER=true \
    ORCHARD__OrchardCore__OrchardCore_Media__MaxFileSize=10485760

WORKDIR /app
COPY .out/app/ ./
COPY ci/docker/entrypoint.sh /app/entrypoint.sh
RUN mkdir -p /app/App_Data && chmod +x /app/entrypoint.sh && chown -R 1654:1654 /app
USER 1654:1654
EXPOSE 8080
ENTRYPOINT ["./entrypoint.sh"]

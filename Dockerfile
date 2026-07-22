FROM node:lts as build

ENV NODE_ENV=production \
    DAEMON=false \
    SILENT=false \
    USER=nodebb \
    UID=1001 \
    GID=1001

WORKDIR /usr/src/app/

COPY . /usr/src/app/

RUN corepack enable

RUN find . -mindepth 1 -maxdepth 1 -name '.*' ! -name '.' ! -name '..' -exec bash -c 'echo "Deleting {}"; rm -rf {}' \;

RUN cp /usr/src/app/install/package.json /usr/src/app/

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install tini

RUN groupadd --gid ${GID} ${USER} \
    && useradd --uid ${UID} --gid ${GID} --home-dir /usr/src/app/ --shell /bin/bash ${USER} \
    && chown -R ${USER}:${USER} /usr/src/app/

RUN mkdir -p /usr/src/app/build/public \
    && chown -R ${USER}:${USER} /usr/src/app/build

USER ${USER}

RUN npm install --omit=dev && rm -rf .npm

FROM node:lts-slim AS final

ENV NODE_ENV=production \
    DAEMON=false \
    SILENT=false \
    USER=nodebb \
    UID=1001 \
    GID=1001

WORKDIR /usr/src/app/

RUN corepack enable \
    && groupadd --gid ${GID} ${USER} \
    && useradd --uid ${UID} --gid ${GID} --home-dir /usr/src/app/ --shell /bin/bash ${USER} \
    && mkdir -p /usr/src/app/logs/ /opt/config/ \
    && chown -R ${USER}:${USER} /usr/src/app/ /opt/config/

COPY --from=build --chown=${USER}:${USER} /usr/src/app/ /usr/src/app/install/docker/setup.json /usr/src/app/
COPY --from=build --chown=${USER}:${USER} /usr/bin/tini /usr/src/app/install/docker/entrypoint.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/tini

# העתקת קובץ ההגדרות לכל הנתיבים האפשריים
COPY --chown=${USER}:${USER} config.json /opt/config/config.json
COPY --chown=${USER}:${USER} config.json /usr/src/app/config.json

USER ${USER}

EXPOSE 4567

# הסרנו מכאן את opt/config/ כדי שלא יידרס בעליית השרת
VOLUME ["/usr/src/app/node_modules", "/usr/src/app/build", "/usr/src/app/public/uploads"]

ENTRYPOINT ["tini", "--", "entrypoint.sh"]

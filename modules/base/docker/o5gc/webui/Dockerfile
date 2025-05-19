FROM o5gc/o5gc-base:jammy AS base

RUN mkdir -p /etc/apt/keyrings                                                \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key   \
        | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg                   \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg]"                \
            "https://deb.nodesource.com/node_20.x nodistro main"              \
        > /etc/apt/sources.list.d/nodesource.list                             \
    && apt-get.sh install nodejs nginx

WORKDIR /o5gc/webui

COPY ./frontend/package*.json ./frontend/
RUN sync-cache.sh download o5gc-webui npm-cache                               \
    && cd frontend                                                            \
    && npm i -g @quasar/cli                                                   \
    && npm install                                                            \
    && sync-cache.sh upload o5gc-webui npm-cache

COPY ./backend/requirements.txt ./backend/
RUN cd backend                                                                \
    && pip --no-cache-dir install -r requirements.txt                         \
    && git clone https://github.com/PodgroupConnectivity/kiopcgenerator.git   \
    && cd kiopcgenerator                                                      \
    && pip --no-cache-dir install -r requirements.txt                         \
    && python3 setup.py install                                               \
    && cd .. && rm -rf kiopcgenerator

FROM base AS frontend
COPY ./frontend ./frontend
RUN cd frontend                                                               \
    && cp -a theme/. src/                                                     \
    && quasar build

FROM base
COPY --from=frontend /o5gc/webui/frontend ./frontend
COPY ./backend ./backend

RUN echo latest > /etc/image_version

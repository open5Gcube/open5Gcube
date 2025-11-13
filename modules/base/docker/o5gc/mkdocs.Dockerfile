FROM minidocks/mkdocs@sha256:b95ba6a3852a4c2ce36b7ce23b0ced4734f54f5fe0f17a45da0d8bd1d1de1fca

RUN pip install --no-cache-dir                                                \
        mkdocs-link-marker mkdocs-open-in-new-tab mkdocs-glightbox            \
        neoteroi-mkdocs

RUN apk upgrade --no-cache                                                    \
    && apk --no-cache add build-base python3-dev pango                        \
    && pip install --no-cache-dir mkdocs-to-pdf

RUN mkdocs -V | sed -E 's|.*version ([0-9.]+).*|\1|' > /etc/image_version

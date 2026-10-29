FROM zensical/zensical@sha256:bb99dcc592fcb0674e92f9e02c051cc293fb5a912b95ee679f2c016e855caf34

RUN pip install --no-cache-dir --root-user-action=ignore neoteroi-mkdocs

RUN zensical --version > /etc/image_version

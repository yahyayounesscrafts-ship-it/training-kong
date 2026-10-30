FROM kong:2.8

COPY ./kong/plugins /kong/plugins

USER kong

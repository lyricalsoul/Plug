#!/bin/bash

mkdir -p .docs

swift package --allow-writing-to-directory .docs/plug \
    generate-documentation --target Plug \
    --disable-indexing \
    --transform-for-static-hosting \
    --hosting-base-path "/plug/" \
    --output-path .docs/plug

swift package --allow-writing-to-directory .docs/plugmacros \
    generate-documentation --target PlugMacros \
    --disable-indexing \
    --transform-for-static-hosting \
    --hosting-base-path "´/plugmacros/" \
    --output-path .docs/plugmacros

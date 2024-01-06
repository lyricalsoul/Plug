#!/bin/bash

mkdir -p .docs

swift package --allow-writing-to-directory .docs/Plug \
    generate-documentation --target Plug \
    --disable-indexing \
    --transform-for-static-hosting \
    --hosting-base-path "/Plug/Plug/" \
    --output-path .docs/Plug

swift package --allow-writing-to-directory .docs/PlugMacros \
    generate-documentation --target PlugMacros \
    --disable-indexing \
    --transform-for-static-hosting \
    --hosting-base-path "/Plug/PlugMacros/" \
    --output-path .docs/PlugMacros
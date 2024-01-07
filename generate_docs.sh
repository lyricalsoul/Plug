#!/bin/bash

mkdir -p .docs

swift package --allow-writing-to-directory .docs \
    generate-documentation --target Plug \
    --disable-indexing \
    --transform-for-static-hosting \
    --hosting-base-path "/" \
    --output-path .docs

# if we have a --dev flag, let's host the docs
if [[ $1 == "--dev" ]]; then
    npx http-server .docs -p 8080
fi
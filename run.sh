#!/bin/bash

echo "1. Started updating submodules"
git submodule update --remote --recursive
echo "1. Finished updating submodules"

mv lcp-docker/base-local/files/credentials.default mv lcp-docker/base-local/files/aws_credentials
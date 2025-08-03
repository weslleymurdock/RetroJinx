#!/bin/bash

set -e

echo "Updating main repositories..."
git pull origin main
git checkout $(git describe --tags `git rev-list --tags --max-count=1`)

echo "Updating Submodules..."
git submodule update --init --recursive


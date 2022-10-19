#!/usr/bin/env bash

# Requirements:
# - curl
# - jq

set -uo pipefail

# Step 1: Find the latest tag
LATEST_TAG=$(curl -L https://api.github.com/repos/protesilaos/iosevka-comfy/tags -s | jq -r '.[0].name')

IOSEVKA_ZIP_FILE=iosevka-comfy-${LATEST_TAG}.zip

# Step 2: download the latest release
curl -L -v https://github.com/protesilaos/iosevka-comfy/archive/refs/tags/${LATEST_TAG}.zip -o ${IOSEVKA_ZIP_FILE}

# Step 3: unzip to local folder that will be iosevka-comfy-${LATEST_TAG}
unzip ${IOSEVKA_ZIP_FILE}

# Step 4: find all unhinted ttf files and repackage them into new zip file
cd iosevka-comfy-${LATEST_TAG} && find . -name "*.ttf" | grep -v unhinted | zip -9 -j ../iosevka-comfy.zip -@ && cd ..

# Step 5: Update Cask File with new version and sha256
SHA256=$(shasum -a 256 iosevka-comfy.zip | awk '{print $1}')

sed -i bak "s/.*version \".*/  version \"${LATEST_TAG}\"/g" ./Casks/font-iosevka-comfy.rb
sed -i bak "s/.*sha256.*/  sha256 \"${SHA256}\"/g" ./Casks/font-iosevka-comfy.rb

# Step 6: create a new tag
# git pull
# git commit --allow-empty -m "Creating Branch ${LATEST_TAG}"
# git tag ${LATEST_TAG}
# git push
# git push --tags origin
# git checkout -b ${LATEST_TAG} main

# git add ./Casks/font-iosevka-comfy.rb
# git commit -m "Update Cask File for ${LATEST_TAG} release"
# git push -u origin ${LATEST_TAG}

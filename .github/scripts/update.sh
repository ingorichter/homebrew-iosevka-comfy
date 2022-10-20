#!/usr/bin/env bash

# Requirements:
# - curl
# - jq

set -uo pipefail

# Step 1: Find the latest tag
LATEST_TAG=$(curl -H "Accept: application/vnd.github+json" -L https://api.github.com/repos/protesilaos/iosevka-comfy/tags -s | jq -r '.[0] | .commit.sha,.name')

readarray -t STRARRAY<<< "${LATEST_TAG}"
declare -p STRARRAY
COMMIT_SHA=${STRARRAY[0]}
LATEST_TAG=${STRARRAY[1]}

# Step 1a: Find the comment from the commit
COMMENT=$(curl -H "Accept: application/vnd.github+json" -L https://api.github.com/repos/protesilaos/iosevka-comfy/git/commits/${COMMIT_SHA} -s | jq -r '.message')

echo "${COMMENT}"

exit 1

ZIPFILE_BASENAME=iosevka-comfy-${LATEST_TAG}
IOSEVKA_ZIP_FILE=${ZIPFILE_BASENAME}.zip
IOSEVKA_ZIP_FILE_TARGET=iosevka-comfy.zip

# Step 2: download the latest release
# curl -v -L --remote-name "https://github.com/protesilaos/iosevka-comfy/archive/refs/tags/${LATEST_TAG}.zip" -o "${IOSEVKA_ZIP_FILE}"
curl -v -L --user-agent "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.74 Safari/537.36" "https://github.com/protesilaos/iosevka-comfy/archive/refs/tags/${LATEST_TAG}.zip" -o "${IOSEVKA_ZIP_FILE}"

# Step 3: unzip to local folder that will be iosevka-comfy-${LATEST_TAG}
unzip "${IOSEVKA_ZIP_FILE}"

# Step 4: find all hinted ttf files and repackage them into new zip file
cd "${ZIPFILE_BASENAME}" && find . -name "*.ttf" | grep -v unhinted | zip -9 -j ../${IOSEVKA_ZIP_FILE_TARGET} -@ && cd ..

# Step 5: Generate sha256 of new zip file
SHA256=$(shasum -a 256 ${IOSEVKA_ZIP_FILE_TARGET} | awk '{print $1}')

# Step 6: Generate list of fonts in zip file
fontNames=$(unzip -Z -1 ${IOSEVKA_ZIP_FILE_TARGET})

# Step 7: Generate new Cask file
cat << CASKFILE > ./Casks/font-iosevka-comfy.rb
cask "font-iosevka-comfy" do
  version "${LATEST_TAG}"
  sha256 "${SHA256}"

  url "https://github.com/ingorichter/homebrew-iosevka-comfy/releases/download/#{version}/iosevka-comfy.zip"
  name "Iosevka Comfy"
  homepage "https://github.com/protesilaos/iosevka-comfy"

  livecheck do
    url :url
    strategy :github_latest
  end

$(for fontName in ${fontNames}; do
    printf "\tfont \"%s\"\n" "${fontName}"
done)
end
CASKFILE

# Step: 8 remove all temp files
rm -rf "${ZIPFILE_BASENAME}"
rm "${IOSEVKA_ZIP_FILE}"
# sed -i "bak" "s/.*version \".*/  version \"${LATEST_TAG}\"/g" ./Casks/font-iosevka-comfy.rb
# sed -i "bak" "s/.*sha256.*/  sha256 \"${SHA256}\"/g" ./Casks/font-iosevka-comfy.rb

# Step 8: create a new tag
# git pull
# git commit --allow-empty -m "Creating Branch ${LATEST_TAG}"
# git tag ${LATEST_TAG}
# git push
# git push --tags origin
# git checkout -b ${LATEST_TAG} main

# git add ./Casks/font-iosevka-comfy.rb
# git commit -m "Update Cask File for ${LATEST_TAG} release"
# git push -u origin ${LATEST_TAG}

# Step 9: upload files for release
export LATEST_TAG COMMENT
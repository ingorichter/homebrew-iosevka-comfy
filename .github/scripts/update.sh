#!/usr/bin/env bash

# Requirements:
# - curl
# - jq

set -uo pipefail

CURL_USERAGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.74 Safari/537.36"

# Step 1: Find the latest tag
LATEST_TAG=$(curl -H "Accept: application/vnd.github+json" -L --user-agent "${CURL_USERAGENT}" https://api.github.com/repos/protesilaos/iosevka-comfy/tags -s | jq -r '.[0] | .commit.sha,.name')

# read the two values from the jq eval into an array
readarray -t STRARRAY<<< "${LATEST_TAG}"
declare -p STRARRAY
COMMIT_SHA=${STRARRAY[0]}
LATEST_TAG=${STRARRAY[1]}

if [ ! -v GITHUB_ENV ] || [ -z "${GITHUB_ENV}" ]
then
    ENV_FILE="github.env"
    echo "" > ${ENV_FILE}
else
    ENV_FILE=${GITHUB_ENV}
fi

# preservere values to create the git tag later in the workflow
echo "COMMIT_SHA=${COMMIT_SHA}" >> "${ENV_FILE}"
echo "LATEST_TAG=${LATEST_TAG}" >> "${ENV_FILE}"

# Step 1a: Find the message from the commit and write it to CHANGELOG.txt
curl -H "Accept: application/vnd.github+json" -L --user-agent "${CURL_USERAGENT}" "https://api.github.com/repos/protesilaos/iosevka-comfy/git/commits/${COMMIT_SHA}" -s | jq -r '.message' > "CHANGELOG.txt"

ZIPFILE_BASENAME=iosevka-comfy-${LATEST_TAG}
IOSEVKA_ZIP_FILE=${ZIPFILE_BASENAME}.zip
IOSEVKA_ZIP_FILE_TARGET=iosevka-comfy.zip

# Step 2: download the latest release
curl -L --user-agent "${CURL_USERAGENT}" "https://github.com/protesilaos/iosevka-comfy/archive/refs/tags/${LATEST_TAG}.zip" -o "${IOSEVKA_ZIP_FILE}"

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
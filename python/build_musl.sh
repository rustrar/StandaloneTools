#!/bin/bash
dp0="$(realpath "$(dirname "$0")")"
set -e

apk update
apk add --no-cache alpine-sdk python3-dev

tool_name="python"
tool_version="3.10.9"
release_date="20221220"
release_url="https://github.com/indygreg/python-build-standalone/releases/tag/20221220"
self_name="$tool_name-$tool_version"
release_version_dirpath="$dp0/release/$self_name"
echo "::set-output name=tool_name::$tool_name"
echo "::set-output name=tool_version::$tool_version"

mkdir -p "$release_version_dirpath" && cd "$dp0/release"
download_url="https://github.com/indygreg/python-build-standalone/releases/download/$release_date/cpython-$tool_version+$release_date-x86_64-unknown-linux-musl-noopt-full.tar.zst"
cpython_zip="$dp0/release/raw_cpython-linux.tar.zst"
echo "download python from $download_url ..."
[[ ! -f "$cpython_zip" ]] && wget "$download_url" -O "$cpython_zip"

echo "download bsdtar ..."
bsdtar_version=3.6.2
bsdtar_download_url="https://github.com/hemnstill/StandaloneTools/releases/download/bsdtar-$bsdtar_version/build-musl.tar.gz"
bsdtar_tar_gz="bsdtar-$bsdtar_version-build-musl.tar.gz"
[[ ! -f "$bsdtar_tar_gz" ]] && wget "$bsdtar_download_url" -O "$bsdtar_tar_gz"
tar -xf "$bsdtar_tar_gz"

bsdtar="$dp0/release/bsdtar"
cpython_bin="$dp0/.tmp/python/install/bin/python3"
if [[ ! -f "$cpython_bin" ]]; then
  echo extract "$cpython_zip" to "$cpython_bin" ...
  rm -rf "$dp0/.tmp/"* && mkdir -p "$dp0/.tmp" && cd "$dp0/.tmp" || exit 1

  "$bsdtar" \
  --exclude="__pycache__" \
  --exclude="test" \
  --exclude="tests" \
  --exclude="idle_test" \
  --exclude="Scripts" \
  --exclude="*.pdb" \
  --exclude="*.whl" \
  --exclude="*.a" \
  --exclude="*.lib" \
  --exclude="*.pickle" \
  --exclude="python/install/include" \
  --exclude="tcl*.dll" \
  --exclude="lib/tcl*" \
  --exclude="tk*.dll" \
  --exclude="lib/tk*" \
  --exclude="python/install/tcl" \
  --exclude="python/install/share" \
  -xf "$cpython_zip" python/install

  strip "$cpython_bin"
fi;

echo "prepare build artifacts ..."
rm -rf "$dp0/release/$self_name" && mkdir -p "$dp0/release/$self_name"
python_scripts_path="$dp0/release/$self_name/Scripts"
cp -rf "$dp0/.tmp/python/install" "$python_scripts_path/"

echo "creating archive ..."
cd "$release_version_dirpath"
{ printf 'Python %s
%s
%s

' "$("$cpython_bin" -c "import sys; print(sys.version)")" "$("$cpython_bin" -m pip --version)" "$download_url"
} > build-musl.md

cat build-musl.md

"$bsdtar" \
  --exclude="__pycache__" \
  --exclude="Scripts/Scripts" \
  --exclude="*.whl" \
  -czvf ../build-musl.tar.gz .
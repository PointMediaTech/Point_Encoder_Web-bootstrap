#!/usr/bin/env bash
# Point Encoder 引導安裝(React spec 2026-10-27-github-release-installer §6.1)。不含任何秘密。
# 先下載再執行(要從 stdin 讀帳密,不能 curl | bash):
#   curl -fsSL https://raw.githubusercontent.com/PointMediaTech/Point_Encoder_Web-bootstrap/main/install.sh -o install.sh
#   sudo bash install.sh [--version X] [其他參數照傳給 point-encoder install]
set -euo pipefail
REGISTRY=ghcr.io/${PE_ORG:-pointmediatech}
PE_ROOT=/opt/point-encoder

version=stable
pass=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) version=$2; shift 2 ;;
        *) pass+=("$1"); shift ;;
    esac
done
if [[ $EUID -ne 0 ]]; then echo "請用 sudo 執行" >&2; exit 1; fi
. /etc/os-release
if [[ "${ID}-${VERSION_ID}" != ubuntu-24.04 ]]; then echo "只支援 Ubuntu 24.04(目前是 ${ID}-${VERSION_ID})" >&2; exit 1; fi

need=()
if ! command -v python3 >/dev/null; then need+=(python3); fi
if ! command -v docker >/dev/null; then need+=(docker.io docker-compose-v2); fi
if (( ${#need[@]} )); then
    apt-get update -q
    DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-upgrade "${need[@]}"
    systemctl enable --now docker
fi

export DOCKER_CONFIG=/run/point-encoder/docker
mkdir -p "$DOCKER_CONFIG"
chmod 700 "$DOCKER_CONFIG"
trap 'rm -rf "$DOCKER_CONFIG"' EXIT
read -r -p "GitHub 帳號:" user
read -r -s -p "GitHub token(read:packages):" token
echo
printf '%s' "$token" | docker login ghcr.io -u "$user" --password-stdin >/dev/null
unset token

img=$REGISTRY/point-encoder-bundle:$version
docker pull --quiet "$img" >/dev/null
tmp=$(mktemp -d)
cid=$(docker create "$img" /none)
docker cp "$cid:/bundle/." "$tmp/"
docker rm "$cid" >/dev/null
ver=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["version"])' "$tmp/release.json")
mkdir -p "$PE_ROOT/releases"
if [[ -d $PE_ROOT/releases/$ver ]]; then rm -rf "$tmp"; else mv "$tmp" "$PE_ROOT/releases/$ver"; chmod 755 "$PE_ROOT/releases/$ver"; fi

PE_INSTALLED_BY=$user "$PE_ROOT/releases/$ver/point-encoder" install --version "$ver" "${pass[@]}"

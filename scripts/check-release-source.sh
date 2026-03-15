#!/bin/bash
set -euo pipefail

pkgver="${1:-0.1.0}"
tag_api_url="https://api.github.com/repos/PIWI10/omarchy-exegol-vm/git/ref/tags/v${pkgver}"
archive_url="https://github.com/PIWI10/omarchy-exegol-vm/archive/refs/tags/v${pkgver}.tar.gz"

echo "Checking release tag: v${pkgver}"
curl -fsSL "$tag_api_url" >/dev/null
echo "Checking release archive: $archive_url"
curl -fI -L "$archive_url" >/dev/null
echo "Release tag and source archive are reachable."

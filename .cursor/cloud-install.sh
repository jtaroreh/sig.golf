#!/usr/bin/env bash
# Cursor Cloud Agent image setup. Idempotent. Disk state is what persists.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export PATH="/usr/local/go/bin:${HOME}/.elan/bin:${PATH}"

if [[ "$(id -u)" -eq 0 ]]; then
  sudo() { "$@"; }
fi

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  git \
  build-essential \
  python3

go_version="go1.27.1"
go_sha="63d339f0da5ab53635a56f2490a7984dfe12dfcff22ad749f63edaf590168445"
if ! command -v go >/dev/null 2>&1 || [[ "$(go env GOVERSION 2>/dev/null || true)" != "${go_version}" ]]; then
  tmp="$(mktemp)"
  curl -fsSL -o "${tmp}" "https://go.dev/dl/${go_version}.linux-amd64.tar.gz"
  echo "${go_sha}  ${tmp}" | sha256sum -c -
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "${tmp}"
  rm -f "${tmp}"
  sudo ln -sfn /usr/local/go/bin/go /usr/local/bin/go
  sudo ln -sfn /usr/local/go/bin/gofmt /usr/local/bin/gofmt
fi

# scripts/setup.sh installs the pinned Lean toolchain, verifier tools, and the
# trusted SigGolf library. Its last step refuses hosts without Landlock and
# systemd user services. Official scoring still needs those; editing does not.
set +e
bash scripts/setup.sh
setup_status=$?
set -e

export PATH="${HOME}/.elan/bin:${PATH}"
if [[ "${setup_status}" -ne 0 ]]; then
  lake exe cache get
  lake build SigGolf
  echo "scripts/setup.sh exited ${setup_status}. Toolchain and SigGolf library are installed. python3 scripts/run.py still needs Landlock ABI 3 and systemd user services."
fi

for bin in elan lean lake; do
  if [[ -x "${HOME}/.elan/bin/${bin}" ]]; then
    sudo ln -sfn "${HOME}/.elan/bin/${bin}" "/usr/local/bin/${bin}"
  fi
done

command -v lake >/dev/null
command -v lean >/dev/null
[[ -f verifier/.tools/env.sh ]]

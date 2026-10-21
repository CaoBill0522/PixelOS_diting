#!/bin/bash
# Bootstrap a fresh Ubuntu 24.04+/Debian 13 box as the diting build server.
# Run as root on the new server:  bash setup-build-server.sh
# Idempotent; safe to re-run.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
pkgs=(git git-lfs curl rsync zip unzip python3 python-is-python3 bc bison flex
      build-essential libssl-dev libxml2-utils xsltproc fontconfig ccache lz4
      zstd m4 libelf-dev cpio kmod sudo openssh-client)
# ncurses runtime name differs between releases
for n in libncurses6 libncurses5; do
    apt-cache show "$n" >/dev/null 2>&1 && pkgs+=("$n") && break
done
apt-get install -y -qq "${pkgs[@]}" >/dev/null

# repo launcher
curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo -o /usr/local/bin/repo
chmod 755 /usr/local/bin/repo

# build user, same keys as root, passwordless sudo
id build >/dev/null 2>&1 || useradd -m -s /bin/bash build
echo "build ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/build
chmod 440 /etc/sudoers.d/build
install -d -m 700 -o build -g build /home/build/.ssh
cp /root/.ssh/authorized_keys /home/build/.ssh/authorized_keys
chown build:build /home/build/.ssh/authorized_keys
chmod 600 /home/build/.ssh/authorized_keys

# 128G RAM is enough for soong; keep a 32G swapfile as a safety net only
if ! swapon --show=NAME --noheadings | grep -qx /swapfile32; then
    fallocate -l 32G /swapfile32
    chmod 600 /swapfile32
    mkswap -q /swapfile32
    swapon -p 10 /swapfile32
    grep -q swapfile32 /etc/fstab || echo "/swapfile32 none swap sw,pri=10 0 0" >> /etc/fstab
fi

# build environment
sudo -u build bash -c '
cd ~
mkdir -p ~/pixelos ~/tmp ~/.ccache-dir
cat > ~/.build_env <<"EOF"
export PATH=$HOME/bin:/usr/local/bin:$PATH
export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
export CCACHE_DIR=$HOME/.ccache-dir
export TMPDIR=$HOME/tmp
EOF
. ~/.build_env
ccache -M 100G >/dev/null
git config --global user.name CaoBill0522
git config --global user.email 150581033+CaoBill0522@users.noreply.github.com
git config --global color.ui false
git lfs install >/dev/null
'

echo "setup done: $(nproc) CPUs, $(free -g | awk "/Mem:/{print \$2}")G RAM"

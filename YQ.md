# YQ

## Installation

How to Install `yq` on systems with no access to snap (i.e. non-Ubuntu / network restricted) (requires that github.com is allowed)

This must be done by installing the binary from GitHub

```bash
cd ~
mkdir ~/bin
wget https://github.com/mikefarah/yq/releases/download/v4.50.1/yq_linux_amd64 -O ~/bin/yq
chmod +x ~/bin/yq
```

Double-check that `~/bin` is in the users PATH: `env | grep PATH`

# Tailscale on Smaller OpenWRT Devices

> [!WARNING]
> This project generates binaries automatically and does not come with any warranty. As of the time of writing, Tailscale v1.58.2 works fine on `Xiaomi Mi Router 4A Gigabit Edition` running `OpenWrt 22.03.3`. Proceed with caution and use this software at your own risk.

This project is a slightly modified version of [this guide](https://openwrt.org/docs/guide-user/services/vpn/tailscale/start#installation_on_storage_constrained_devices).

## Installation

### Pre-requisites

Set the environment variables for the Tailscale version and your router's architecture:

```sh
export VERSION="1.58.2"
export ARCH="mips_24kc"
```

### 1. Compile a Portable `tailscale.combined` Binary for Your Device

- Clone the Tailscale repository and checkout to the release you are building for:

```sh
git clone https://github.com/tailscale/tailscale
cd tailscale
git checkout v$VERSION
```

Follow [this guide](https://tailscale.com/kb/1207/small-tailscale#step-3-compressing-tailscale) to build the `tailscale.combined` binary for your device.

> [!NOTE]
> Set the `GOOS` and `GOARCH` environment variables when building to cross-compile the binary for your device. For example:

```sh
GOOS=linux GOARCH=$ARCH go build -o tailscale.combined -tags ...
```

> [!NOTE]
> The value of `$ARCH` might not always match the `GOARCH` environment variable. Verify the correct `GOARCH` value based on your device's architecture. For more details on supported values, refer to [this guide](https://gist.github.com/asukakenji/f15ba7e588ac42795f421b48b8aede63).

- Run the final built `tailscale.combined` through `upx` to compress it:

```sh
upx --lzma --best ./tailscale.combined
```

### 2. Download the IPK

```sh
wget https://github.com/du-cki/openwrt-tailscale/releases/download/v$VERSION/tailscale_$VERSION-1_$ARCH.ipk
```

### 3. Move Files to Your Router

- Transfer the `tailscale.combined` binary and the IPK file to your router's `/tmp` directory:

```sh
scp -O ./tailscale.combined root@openwrt.lan:/tmp
scp -O tailscale_$VERSION_$ARCH.ipk root@openwrt.lan:/tmp/tailscale.ipk
```

### 4. Install Dependencies and Tailscale

```sh
opkg update
opkg install kmod-tun iptables-nft
opkg install /tmp/tailscale.ipk
```

### 5. Use the Portable Version of Tailscale

- Replace the installed `tailscale` and `tailscaled` binaries with the portable version:

```sh
rm /usr/sbin/tailscaled
rm /usr/sbin/tailscale
cd /usr/sbin
cp /tmp/tailscale.combined .
ln -s tailscale.combined tailscaled
ln -s tailscale.combined tailscale
```

- Verify your installation:

```sh
tailscale --version
```

If you see an error, it means that the `tailscale.combined` binary is not compiled for the correct architecture. Remove the `tailscale.combined` binary and compile it again for the correct architecture.

### 6. Start Tailscale

- Restart the Tailscale daemon:

```sh
service tailscale restart
```

- Start Tailscale with the `--netfilter-mode=off` flag to prevent iptables rules from being created. This setting will be preserved in `/etc/tailscale/tailscaled.state` for future boots:

```sh
tailscale up --netfilter-mode=off
```

---
layout: post
title: 'Rpi 4B，mDNS 与 deploy-rs'
date: 2021-09-21
cover: 'https://raw.githubusercontent.com/serokell/deploy-rs/master/docs/logo.svg'
---

> Credit:

只是打算写一下最近都做了什么。

### mDNS

拿到 Rpi 4B，早期部署 NixOS 的时候，经常会用到代理。只要打开笔记本上的防火墙端口，以及 CfW ([Clash for Windows](https://github.com/Fndroid/clash_for_windows_pkg)) 中的 "Allow LAN" 选项，在 Rpi 上就可以使用主机的代理了。

说到 CfW，它原来是 Windows only 的，现在三平台都可用，名字却没有改，它用的是电子 ([Electron](https://www.electronjs.org/))。顺便说一下，CfW 使用的是 clash 的未开源的高级版本，看起来不太清真。

这是较为基础的操作，但我并不满足于此。虽说路由器分给我设备的 IP，大概率是不会变的，并且我也可以在路由器上进行 IP 与 MAC 绑定。但我却觉得使用 IP 进行通信较为麻烦且不够优雅，故打算使用 mDNS 进行局域网内的域名转换。

mDNS 是 [Multicast DNS](https://en.wikipedia.org/wiki/Multicast_DNS) 的缩写，就是用来做上面说的那些事情的。从名字也能听出来，它的实现方式是通过广播。下面是 [@Yuuta](https://github.com/Trumeet) 的个人理解：

> avahi 我个人理解本身就是个 mdns 实现？  
> 我也不太懂，但就是一个整天给 5353 广播东西的玩意

妮可草老师 (@NickCao) 则建议我使用 systemd 配置，因为可以少装 avahi 这个包。那么对应的 Arch Wiki 在这里：[systemd-resolved](https://wiki.archlinux.org/title/Systemd-resolved#mDNS)。

不过最后我还是用回了 avahi，这倒不是说 systemd 不好，而是 NixOS 模块的一个小问题。

我的 NixOS 中，有着类似 `networking.interfaces.<name>.useDHCP = true;` 配置的存在，它会自动生成一个 `.network` 文件在 `/etc/systemd/network/` 下。由于 systemd 的服务排序规则，最好在其文件前加入优先级前缀，变为 `xx-name.network`。模块的作者都假定它们具有优先级 40，所以生成出的文件自然是 `40-name.network` 这样的形式。

（此模块的具体实现代码：[nixos/modules/tasks/network-interfaces-scripted.nix#L58](https://github.com/NixOS/nixpkgs/blob/8284fc30c84ea47e63209d1a892aca1dfcd6bdf3/nixos/modules/tasks/network-interfaces-scripted.nix#L58)）

这就导致了一个什么问题呢？虽然 NixOS 模块可以帮我生成配置，我当然也可以在里面写一些额外的配置。比如上述 Arch Wiki 中的 `[Network]` - `MulticastDNS=yes`，在我这里需要写成 `systemd.network.networks.<name>.extraConfig = "MulticastDNS=yes";`。但这里的 name 指的不是接口的名称，而是 `.network` 文件的名称，这就需要我手动写上前缀 `40-`，对吧？

这就导致了，这个前缀 `40-` 已经变成了 API 导出的一部分。如果后续模块的作者不打算用 40 优先级，我的配置就会莫名其妙坏掉。这使得我非常难以接受，所以干脆用 avahi 了，它的配置要简单得多：

```````Nix
# https://github.com/NixOS/nixpkgs/issues/98050#issuecomment-860272122
services.avahi = { enable = true; nssmdns = true; };
services.avahi.publish = { enable = true; domain = true; addresses = true; };
```````

启用 avahi，并让其发布主机的域名与地址，配置就算完成了。这就是 NixOS 的魅力所在。

### deploy-rs

接下来来说一个很好玩的东西，[deploy-rs](https://github.com/serokell/deploy-rs)。一个使用了 Nix 的服务器集群部署工具，这些天我的体验非常不错。我用它直接部署树莓派的配置，它在笔记本上预编译好所有的东西，然后再发给树莓派用。就算树莓派没有网络也没有问题。

由于我手里这一批次的设备较新，内核在读取 SD 卡时会遇到问题，需要多加一个设备树上去。（参见先前的博客：[Raspberry Pi 4B 与 NixOS](../20/rpi-nixos.html)）。显然在树莓派上 build 是不太现实的。

这个工具完美解决了我的需求，并且它是跨架构 + 自动的，这就已经很 crazy 了。

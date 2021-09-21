---
layout: post
title: 'rpi 4B + NixOS 踩坑小记 - WiFi'
date: 2021-09-21
cover: 'https://www.thorntech.com/wp-content/uploads/2018/04/nixos-logo-800px.jpg'
---

> Thanks helping from @NickCao & @nanoApe!

这篇文章是昨天 blog [Raspberry Pi 4B 与 NixOS](../20/rpi-nixos.html) 的后续。

昨天解决完 rpi 4B 不读卡的问题，今天就要正式安装 NixOS 了，首先是 WiFi 问题。

在文章开始之前，我想说明一些 NixOS 的特性及特点。Nix 是一套 [构建系统](https://zh.wikipedia.org/wiki/%E7%B5%84%E5%BB%BA%E8%87%AA%E5%8B%95%E5%8C%96)，正如 [CMake](https://cmake.org/) 之于 C / C++，[Gradle](https://gradle.org/) 之于 Java / Kotlin。而 [Nix](https://zh.wikipedia.org/wiki/Nix_%E5%8C%85%E7%AE%A1%E7%90%86%E5%99%A8) 是一个包管理器，却不仅仅局限于构建软件包，它甚至可以用于构建 img 镜像。

[NixOS](https://en.wikipedia.org/wiki/NixOS) 则是一个 Linux 发行版，它采用 Nix 来管理操作系统中包括 Linux 内核的所有部分。辅以 [nixpkgs](https://github.com/NixOS/nixpkgs) 中的大量模块，为日常使用、服务器部署等场景提供了大量便利。

### 构建启动镜像

要构建出 rpi 的启动镜像，只靠 x86_64 的机器肯定是不行的。我们需要有 ARM 架构的服务器，或进行一些特殊的操作：[NixOS on ARM](https://nixos.wiki/wiki/NixOS_on_ARM#Build_your_own_image)。在上述的 NixOS wiki 中，我们需要启用 [binfmt](https://zh.wikipedia.org/wiki/Binfmt_misc)，NixOS 会帮我们启动一个 aarch64 的 QEMU 虚拟机，并在其中进行编译。

要针对 aarch64 启用 binfmt，只需将这一行加入 NixOS 主配置，重建切换即可：

```````Nix
boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
```````

接下来需要准备要构建 img 文件的配方，这在 Nix 中被称为 dervation：

```````Nix
{ ... }：{
  imports = [
    <nixpkgs/nixos/modules/installer/sd-card/sd-image-aarch64-installer.nix>  
  ];
}
```````

我们直接将 nixpkgs 中的 `sd-image-aarch64-installer.nix` 文件引入进来即可，同时可以在 imports 块外面写自己的配置，比如为树莓派配置自动连接 WiFi。

根据 wiki - [wpa_supplicant](https://nixos.wiki/wiki/Wpa_supplicant)，我添加以下内容：

```````Nix
networking.wireless.enable = true;
networking.wireless.networks = { "@Ruijie-s02C6".psk = "Jxustnc001"; };
```````

这之后就可以构建 img 了，命令如下。因为我们需要在 aarch64 QEMU 中进行构建，参数 `--argstr system aarch64-linux` 是必不可少的。

```````Bash
nix-build '<nixpkgs/nixos>' \ 
  -A config.system.build.sdImage \ 
  --argstr system aarch64-linux \ 
  -I nixos-config=./sd-image.nix
```````

### 写入镜像

根据树莓派官方文档 [Installing Images on Linux](https://www.raspberrypi.org/documentation/computers/getting-started.html#installing-images-on-linux)，我写入镜像的命令如下：

```````Bash
sudo dd \ 
  if=nixos-sd-image-21.05.3248.6120ac5cd20-aarch64-linux.img of=/dev/sdb \ 
  bs=4M conv=fsync status=progress
```````

### WiFi 踩坑开始

构建完成后踩坑正式开始，我的树莓派并没有连上 WiFi，systemctl 查看 wpa_supplicant 服务状态后得到错误码 `CTRL-EVENT-ASSOC-REJECT`，以下是各种尝试：

 - 禁用 wmm：[https://www.raspberrypi.org/forums/viewtopic.php?t=198104](https://www.raspberrypi.org/forums/viewtopic.php?t=198104)
 - HDMI 对 WiFi 造成干扰：[https://www.raspberrypi.org/forums/viewtopic.php?t=274715](https://www.raspberrypi.org/forums/viewtopic.php?t=274715)
- 关闭 [快速 BSS 切换](https://zh.wikipedia.org/wiki/IEEE_802.11r-2008)：[https://raspberrypi.stackexchange.com/questions/77144/rpi3-wireless-issue-ctrl-event-assoc-reject-status-code-16](https://raspberrypi.stackexchange.com/questions/77144/rpi3-wireless-issue-ctrl-event-assoc-reject-status-code-16)
 - .......（这并不是什么愉快的回忆）

### 转机

由于先前的报错太过于模糊，反倒掩盖了真实的问题。在一天将要结束之时，我使用 Android 手机开了一个热点，发现树莓派可以进行连接。逐步尝试后，定位到问题在与 5GHz 上，手机 5GHz only 热点下也仍然是相同的状况。

最后的解决方案是由 [@nanoApe](https://github.com/Konano) 提供的。他之前也遇到过此问题，并为我找出了相关的 issues ([raspberrypi/firmware/#1359](https://github.com/raspberrypi/firmware/issues/1359))。我们首先需要一点背景知识。

WiFi 的频率在各个国家都有规定，且各有不同。例如最大的发射功率和配制方式等技术细节。Linux 设备也必须支持这些规定，以便在全球范围内使用。自然而然的，内核中存在一个这样的数据库，以存放各个国家的详细通信规则。详细说明请参见 Wikipedia - [WLAN 信道列表](https://zh.wikipedia.org/wiki/WLAN%E4%BF%A1%E9%81%93%E5%88%97%E8%A1%A8)。

根据上述 issues，这个数据库没有得到及时更新，所以导致某些 5GHz WiFi 的频道缺失。可以通过更新该 db 或切换路由器的发射频道来解决。于是我将路由器中的 “健康模式”（以 5GHz 最低功率的频道运行）关闭，问题便得以解决。

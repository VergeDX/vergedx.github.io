---
layout: post
title: '关于两个 Nix 的 “bug” - Chromium & Recursion'
date: 2021-10-05
cover: 'https://miro.medium.com/max/1400/1*ZUH2k05-kVg19QmzwvKdPw.png'
---

> The Nix expression language is a pure, lazy, functional language.

最近日常使用 NixOS 的过程中，遇到了两个奇怪的问题。

### 1. nix build 爆内存

正如 Quote 所言，Nix 表达式语言是一种纯粹的、惰性的、函数式语言。这种特性造成了今天要讲的第一个问题 \-- nix build 内存爆炸。

根据 GitHub issues [NixOS/nixpkgs #139865](https://github.com/NixOS/nixpkgs/pull/139865) 中的描述，我先是写了一个 uboot.nix：

```````Nix
{ pkgs ? import <nixpkgs> { } }:
pkgs.pkgsCross.aarch64-multiplatform.ubootRaspberryPi4_64bit.overrideAttrs (old: {
  patches = old.patches ++ [
    (pkgs.fetchpatch {
      url = "https://patchwork.ozlabs.org/series/259129/mbox/";
      sha256 = "04x55a62a5p4mv0ddpx7dnsh5pnx46vibnq8cry7hgwf4krl64gl";
    })
  ];
})
```````

然后执行 `nix-build uboot.nix` 后，是正常 build 出了 `u-boot-rpi4.bin`，这里没有什么问题。

这之后为了 build sdImage 方便，我将其写进 `flake.nix` 中，做成 overlays：

```````Nix
{
  nixpkgs.overlays = [
    (self: super: {
      ubootRaspberryPi4_64bit = super.callPackage ./uboot.nix { };
    })
  ];
}
```````

并加在 `flake.nix` 中的 `modules` 里，就像这样：[VergeDX/PoC - flake.nix](https://github.com/VergeDX/PoC/blob/master/flake.nix)。其中，`"${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"` 是用于构建 sdImage 的。可以参考一下 [之前的博客](../../09/21/rpi-nixos-details.html)。

这看起来并没有什么问题。当然如果要用 overlays 的话，也可以直接在 overlays 里 overrideAttrs，没必要 callPackage。但这确是出现问题的地方。

我将相关代码另外单独放了一处 repo，有兴趣的朋友可以自己尝试一下：[VergeDX/PoC](https://github.com/VergeDX/PoC)。使用命令 `nix build .#nixosConfigurations."recurrent".config.system.build.sdImage` 即可构建。

在我发现问题前，我跑了 nix build 一段时间后，我发现我的系统整个卡住了。最后通过 [Magic SysRq 组合键](https://en.wikipedia.org/wiki/Magic_SysRq_key) 才捡回一条命。我的机器配备了 32G 的内存，不存在内存不足的情况。

这之后我进行了多次实验与观察，发现跑完 nix build 后，内存一直在增长。同时 nix 进程也不吃 signal，只能通过 kill -9 来杀死。并且似乎是卡在 eval 阶段，因为无论是 -vL 还是 --dry-run 都不输出任何内容。

与 @NickCao 老师以及 @yinfeng 讨论后，爆内存的原因终于被找到了。首先需要注意的是 `uboot.nix` 的第一行，它引用 pkgs 或导入 nixpkgs。由于这是 flakes，而 `import <nixpkgs>` 是 impure 的。但该命令并未报 impure 错误，以为此处的 pkgs 是 flakes 中 nixpkgs 的 pkgs 属性，也即 `nix repl` 中的 pkgs.pkgs。

而 pkgs.pkgs 则是 pkgs 本身，这也意味着可以 pkgs.pkgs.pkgs... 一直写下去。这就导致了 patches 变量一直在被 ++，始终无法收敛，最后内存爆炸。这并不是 Nix 的 bug。

> @NickCao 老师：不过 til (Today I Learned)

### 2. Chromium 与 xdg-open 的问题

下一个问题是关于 chromium 包的。问题是这样的，某天开始我发现，如果从别的 app 调用 Chromium 打开新标签页，Chromium 仅仅显示一个空白的 New Tab。比如在 [Albert](https://albertlauncher.github.io/) 中搜索东西时，或者 Telegram / [Alacritty / Kitty 终端] 中点击链接时，又或者在 VSCode 中进行三方登陆时。在这些场景下 Chromium 都只会弹一个新窗口出来，但却是空白页。

本来我以为这只是 Chromium 的 bug，因为 `google-chrome` 包和 `firefox` 包均无此问题，就没有放在心上。但它不能正常工作又有些讨厌，于是打算尝试修一修。找到了这一篇问答：

[xdg-open only opens a new tab in a new Chromium window despite passing it a URL](https://askubuntu.com/questions/540939/xdg-open-only-opens-a-new-tab-in-a-new-chromium-window-despite-passing-it-a-url)

这里说的是在 Desktop entity 里，chromium %U 中的 %U 在 xdg-open 时会被换成 url，从而打开新标签页。于是我检查了一下 chromium, google-chrome, firefox 包中的 .desktop 文件，没看出什么端倪。

然后我试了一下 `chromium https://baidu.com`，发现症状得以复现，于是我看了一下 chromium 的启动脚本（仅贴出最后四行）：

```````Nix
exec "/nix/store/blqad79va9mw2mwimhi4mvya0jbrrrvs-chromium-unwrapped-94.0.4606.71/libexec/chromium/chromium"  --enable-gpu-rasterization \
--enable-zero-copy \
--enable-features=VaapiVideoDecoder
 "$@"
```````

这里的三个 \--enable-xxx flag 是我用 override 里的参数 `commandLineArgs` 传进去的。它接收一个字符串，并写在 chromium 的启动脚本里。由于最后那个多出来的换行，导致 "$@" 被删去，而它本来应该是 url 的占位符。又由于是 exec chromium ，所以执行完也不会报错，url 就这样给忽略掉了。

解决的方法也非常简单，多加一个反斜杠就好了：[VergeDX/config-nixpkgs #a7c6a12](https://github.com/VergeDX/config-nixpkgs/commit/a7c6a126a507888b3467f53154a4b1c2fb4d0f30)。

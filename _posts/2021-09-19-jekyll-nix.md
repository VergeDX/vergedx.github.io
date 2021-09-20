---
layout: post
title: 'Jekyll 博客搭建与 Nix 部署'
date: 2021-09-19
cover: 'https://www.jekyll.com.cn/img/jekyll-og.png'
---

> Nix is awesome.

首篇博客自然是要讲述搭建的过程，对于这次开始写博客，我仍然选择使用 [kaeyleo/jekyll-theme-H2O](https://github.com/kaeyleo/jekyll-theme-H2O) 主题。
不过这个项目已经有两年多时间没有更新了，可谓是年久失修。就连其使用的框架 [Jekyll](https://jekyllrb.com/) 也早已经历了一次大版本更新 (4.x)，无法使用这个主题。  

再加上我使用的是较为特殊的 [NixOS](https://nixos.org/)，跑起这个项目就成为了第一个目标。

经过一番搜索，找到了一篇博客 ([Using Jekyll and Nix to blog](https://nathan.gs/2019/04/19/using-jekyll-and-nix-to-blog/))，使用 nix-shell (bundlerEnv) + 一个 script 解决了这个问题，最终提交见 [#bc6255e](https://github.com/VergeDX/vergedx.github.io/commit/bc6255e2b2b5022c9e18bd6ba69cf46494af7013)。

GitHub pages 默认使用了较新版本的 Jekyll 帮我编译 blog，所以部署这件事情还得自己来。只需把 jekyll 命令换为 `jekyll build`，上传 `_site/*` 到另一个部署分支即可。一年前我在另一个 GitHub pages 这样做过，所以还记得。

我使用 [Neovim](https://neovim.io/) 编辑 GitHub Actions 的 yml 时，意外发现我所使用的 YAML LSP ([redhat-developer/yaml-language-server](https://github.com/redhat-developer/yaml-language-server)) 支持对 GitHub Actions 的语法进行补全，但其项目首页似乎并未写明这一特性。

在最终的 GitHub Actions script 中，直接用 [Install Nix](https://github.com/marketplace/actions/install-nix) 装好 Nix，用 `sed` 替换一下 jekyll 命令，然后跑 server.sh 就已经是构建过程了。最后用 [ad-m/github-push-action](https://github.com/ad-m/github-push-action) 强推一下 deploy 分支就好，还算是方便。

---
layout: post
title: '集群监控，TICK 技术栈，以及 agenix'
date: 2021-10-02
cover: 'https://www.influxdata.com/wp-content/uploads/influx-regular-black.jpg'
---

> Telegraf \| InfluxDB \| Chronograf \| Kapacitor.

### TICK Stack

今天的主角是 [TICK 技术栈](https://wiki.archlinux.org/title/TICK_stack) 。它是四个开源组件的集合，结合起来提供一个平台，用于存储、捕获、监控和可视化时间序列数据（Arch Wiki）。这四个开源组件分别是：

 - [**T**elegraf](https://www.influxdata.com/time-series-platform/telegraf/) - 用于从物联网设备等一系列来源中收集时序数据。
 - [**I**nfluxDB](https://www.influxdata.com/) - 用于处理大量时序数据的高性能数据库，由 [Golang](https://golang.org/) 写成。
 - [**C**hronograf](https://www.influxdata.com/time-series-platform/chronograf/) - 对于 InfluxDB 1.x 数据的实时可视化。
 - [**K**apacitor](https://www.influxdata.com/time-series-platform/kapacitor/) - 基于 InfluxDB 数据视图的异常监控和警报。

Arch Wiki 中的 Note 表示，不必全部使用这些组件。例如可以将 Chronograf 换为 [Grafana](https://grafana.com/)，或不使用 Kapacitor 监控。

事实上也的确是这样的，前不久 InfluxDB 推出了 2.x 版本，自身就已集成了数据可视化 + 监控 & 预警。我也只配置了前两个，另外还有一个 Nginx。

我们 NixOS 装这些东西可简单了，只需要 enable 一下就行。另外我的内网（校园网以及 WiFi）都不能算安全，我又生成了自签证书给 InfluxDB 用上。文档在这里：

[https://docs.influxdata.com/influxdb/v2.0/security/enable-tls/](https://docs.influxdata.com/influxdb/v2.0/security/enable-tls/)

配置好 InfluxDB，你可以去 127.0.0.1:8086 进行一些初始设置，创建初始帐号、组织、buckets 等。接下来就要配 Telegraf 了。

Telegraf 是数据采集服务，我们光有 InfluxDB 显然不行。在 InfluxDB 面板里，Load Data -> Telegraf -> Create a Configuration 里就可以创建配置了，我选了 System 和 Nginx。

接下来它也有提示，我们需要 INFLUX_TOKEN 和配置文件的链接，想办法传进 systemd 里就行了。我的话还得把自签证书写里面，这里 @NickCao 老师建议我用 systemd 的 [LoadCredential](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#Credentials)。

配置 Telegraf 的时候，InfluxDB 也会生成一个漂亮的 Dashboard。

### Flux

InfluxDB 的查询语言也挺好玩的。在 1.x 时代，只有 InfluxQL 语言可以用，它似乎是一个近似 SQL 的语言。2.x 起可以使用 Flux 语言进行查询，我放一个文档在这里：

[https://docs.influxdata.com/flux/v0.x/](https://docs.influxdata.com/flux/v0.x/)

之前在群里看到 [@Harry Chen](https://github.com/Harry-Chen) 写过 Flux，特殊的语法配上连字，一下子就引起了我的注意。

### agenix

[age](https://github.com/FiloSottile/age) 是一个简单、现代又安全的加密工具、加密格式，agenix 自然是将其引入到 Nix 中，使得 Nix 用户更方便地管理 Token 等 secret。你可以将文件加密后，再放进配置中一起开源。

它的文档说明十分详细，因此我也在这里放一个文档：

[https://github.com/ryantm/agenix](https://github.com/ryantm/agenix)

基本上就是编辑一下 secrets.nix 和 configuration.nix，再用 `agenix -e 'file_name'` 命令来编辑私密文件。文件将会解密后放在 /run/secrets/ 下，你也可以在配置中调整它们的所有者。

---
title: rpc【1】概述
toc: true
categories:
  - rpc框架
tags:
  - rpc
hide: true
sortn: 10
date: 2021-08-01 17:49:05
---

rpc学习 之 概述
<!-- more -->

------



# rpc概述



## rpc定义：

​	像调用本地方法一样调用远程服务。



## rpc功能概述

### consumer功能分析

![consumer模块](https://cdn.jsdelivr.net/gh/coolflameSLZ/img/img20210801182613.png)

#### 连接管理，connect manager

- 初始化时机
- 连接数维护
- 心跳、重连机制



#### 负载均衡

#### 请求路由

#### 超时处理

#### 健康检查



### provicer功能分析

#### 队列/线程池

#### 超时丢弃

#### 优雅关闭

#### 过载保护


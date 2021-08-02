---
title: kafka【1】概述
toc: true
categories:
  - 消息系统
  - kafka
tags:
  - kafka
hide: false
sortn: 10
date: 2021-08-02 12:07:04
---


<!-- more -->

------



# kafka【1】概述



## 消息队列的两种模式

### 点对点模式 (一对一)

- 消费者主动拉取数据消息，消息拉取后，queue 中不再存储。
- 支持存在多个消费者，但是一个消息只能有一个消费者可以消费



### 发布/订阅模式 (Pub/Sub)

- 消费者拉取数据后不会立即清除信息，但是保留是有期限的
- 消息provider将消息发布到 Topic 中，同时有多个consumer订阅消息。 发布到 Topic 的消息会被所有订阅者消费
- 发布/订阅模式的队列又分为
  - 消费者主动 pull (Kafka)
  - broker 主动 push



![kafak机构图](https://cdn。jsdelivr.net/gh/coolflameSLZ/img/img20210802121218.png)

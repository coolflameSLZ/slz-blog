---
title: kafka【5】命令行工具
toc: true
categories:
  - 消息系统
  - kafka
tags:
  - kafka
hide: false
sortn: 50
date: 2021-08-02 16:24:12
---


<!-- more -->

------



## 命令行工具

### 生产消息

生产消息使用 kafka-console-producer 脚本：


```shell
$ bin/kafka-console-producer.sh --broker-list kafka-host:port --topic test-topic --request-required-acks -1 --producer-property compression.type=lz4
```



### 消费消息

```shell
$ bin/kafka-console-consumer.sh --bootstrap-server kafka-host:port --topic test-topic --group test-group --from-beginning --consumer-property enable.auto.commit=false 
```



### 测试生产者性能

```shell
$ bin/kafka-producer-perf-test.sh --topic test-topic --num-records 10000000 --throughput -1 --record-size 1024 --producer-props bootstrap.servers=kafka-host:port acks=-1 

#返回值
linger.ms=2000 compression.type=lz4 2175479 records sent, 435095.8 records/sec (424.90 MB/sec), 131.1 ms avg latency, 681.0 ms max latency. 4190124 records sent, 838024.8 records/sec (818.38 MB/sec), 4.4 ms avg latency, 73.0 ms max latency. 10000000 records sent, 737463.126844 records/sec (720.18 MB/sec), 31.81 ms avg latency, 681.00 ms max latency, 4 ms 50th, 126 ms 95th, 604 ms 99th, 672 ms 99.9th.
```

- 上述命令， 向指定主题发送了 1 千万条消息，每条消息大小是 1KB，

- 上述输出，表明测试生产者生产的消息中，有 99% 消息的延时都在 604ms 以内。

  你完全可以把这个数据当作这个生产者对外承诺的 SLA。



### 测试消费者性能

```shell
$ bin/kafka-consumer-perf-test.sh --broker-list kafka-host:port --messages 10000000 --topic test-topic 
#返回值
start.time, end.time, data.consumed.in.MB, MB.sec, data.consumed.in.nMsg, nMsg.sec, rebalance.time.ms, fetch.time.ms, fetch.MB.sec, fetch.nMsg.sec 2019-06-26 15:24:18:138, 2019-06-26 15:24:23:805, 9765.6202, 1723.2434, 10000000, 1764602.0822, 16, 5651, 1728.1225, 1769598.3012
```



### 查看topic消息总数

```shell
#最早位移
$ bin/kafka-run-class.sh kafka.tools.GetOffsetShell --broker-list kafka-host:port --time -2 --topic test-topic
 
test-topic:0:0
test-topic:1:0

#最新位移
$ bin/kafka-run-class.sh kafka.tools.GetOffsetShell --broker-list kafka-host:port --time -1 --topic test-topic
 
test-topic:0:5500000
test-topic:1:5500000

```

- 消息总数 =  最早位移 + 最新位移

- 对于本例，test-topic 总的消息数为 5500000 + 5500000，等于 1100 万条。

  

### 查询消费者组位移

```shell
$ bin/kafka-console-consumer-groups.sh --bootstrap-server kafka-host:port --describe --group test-group
```

- CURRENT-OFFSET 表示该消费者当前消费的最新位移，
- LOG-END-OFFSET 表示对应分区最新生产消息的位移，
- LAG 列是两者的差值。

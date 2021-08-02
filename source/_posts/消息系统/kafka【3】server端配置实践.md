---
title: kafka【3】server端配置实践
toc: true
categories:
  - 消息系统
  - kafka
tags:
  - kafka
hide: false
sortn: 30
date: 2021-08-02 12:44:22
---

这是摘要
<!-- more -->

------



## **Broker 端参数**

### 基本配置

#### log.dirs

- 这是非常重要的参数，指定了 Broker 需要使用的若干个文件目录路径。
- 在线上生产环境中一定要为log.dirs配置多个路径，具体格式是一个 CSV格式，也就是用逗号分隔的多个路径，比如/home/kafka1,/home/kafka2,/home/kafka3
- 如果有条件的话你最好保证这些目录挂载到不同的物理磁盘上 多块物理磁盘同时读写数据有更高的吞吐量。 能够实现故障转移



### 配置zookeeper

####  zookeeper.connect

- 非常重要的参数，代表了zk的地址。
- 这也是一个 CSV 格式的参数，比 如我可以指定它的值为 zk1:2181,zk2:2181,zk3:2181。2181 是 ZooKeeper 的默认端口。
- 如果你有两套 Kafka 集群，假设分别叫它们 kafka1 和 kafka2，那么两套集群的zookeeper.connect参数可以这样指定:
  - zk1:2181,zk2:2181,zk3:2181/kafka1和 zk1:2181,zk2:2181,zk3:2181/kafka2。
  - kafkaName 只需要写一次，而且是加到最后的。<br>反例 : zk1:2181/kafka1,zk2:2181/kafka2,zk3:2181/kafka3，这样的格式是不对的。



### Broker连接

#### compression.type

设置成producer，要按照生产者压缩格式来，防止 broker出现消息解压缩。

#### unclean.leader.election.enable

unclean.leader.election.enable = false。 如果一个 Broker 落后原先的 Leader 太多，那么它一旦成为新的Leader，必然会造成消息的丢失。故一般都要将该参数设置成 false

#### replication.factor

replication.factor 配置要大于等于3。 最好将消息多保存几份，毕竟目前防止消息丢失的主要机制就是冗余

#### min.insync.replicas

min.insync.replicas 至少要大于1。 本属性代表，消息至少要被写入到多少个副本才算是“已提交”。设置成大于 1 可以提升消息持久性。

确保 replication.factor > min.insync.replicas。 推荐设置成 replication.factor = min.insync.replicas + 1。



### Topic管理

#### auto.create.topics.enable

是否允许自动创建 Topic。建议否，由运维管理，要不然乱七八糟的topic满天飞。

#### unclean.leader.election.enable

是否允许 Unclean Leader 选举。建议你还是显式地把它设置成 false

#### auto.leader.rebalance.enable

是否允许定期进行 Leader 选举，建议在生产环境中把这个参数设置成 false，系统正常运行，没必要整活



### 数据留存

#### log.retention.{hour|minutes|ms}

都是控制一条消息数据被保存多长时间，根据业务需求来。

#### log.retention.bytes

这是指定 Broker 为消息保存的总磁盘容量大小 

#### message.max.bytes

控制 Broker 能够接收的最大消息大小。<br>默认的 1000012 (1MB)太少了，因此在线上环境中设置一个比较大的值比较保险。根据业务情况来

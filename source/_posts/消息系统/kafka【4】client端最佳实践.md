---
title: kafka【4】client端最佳实践
toc: true
categories:
  - 消息系统
  - kafka
tags:
  - kafka
hide: false
sortn: 40
date: 2021-08-02 13:19:51
---


<!-- more -->

------

# kafka【4】client端最佳实践



## 生产者分区策略

### 分区策略的意义

- 分区实际上是调优Kafka并行度的最小单元

- 所谓分区策略是决定生产者将消息发送到哪个分区的算法。

- 如果一个topic分区越多，理论上整个集群所能达到的吞吐量就越大。

  

### 自带的分区策略

#### 轮询策略

- 能保证消息最大限度地被平均分配到所有分区上，故默认情况下它是最合理的分区策略

#### 随机策略

- 如果追求数据的均匀分布，还是使用轮询策略比较好，随机策略暂时没想到场景

#### 按照key分区 Key-ordering 策略

- 一旦消息被定义了 Key，则使用 key-ordering 策略，同一个 Key 的所有消息都进入到相同的partition
- kafka只能保证同partition下的消息处理都是有顺序的，partition间无法做到有序。
- 如果所有数据都用这一个key，会导致分区数据不平衡，降低吞吐量。所以建议使用区分度较大的值作为key。比如 uid，pid，不要使用 status、if_xxx等
- 没有找到一个区分度大的key，又要保持顺序，则不要使用kafka，rocketMq不错。



### 自定义分区策略

- 编写生产者程序时，可以自定义分区策略接口 

```java
// org.apache.kafka.clients.producer.Partitioner 
int partition(String topic, Object key, byte[] keyBytes, Object value, byte[] valueBytes, Cluster cluster)

List<PartitionInfo> partitions = cluster.partitionsForTopic(topic); 
return Math.abs(key.hashCode()) % partitions.size();

```





## producer 端配置实践



### 生产者基本配置

#### 消息版本

Producer 和 Broker 的消息版本要统一（如果不统一，Broker要进行消息解析）

#### 压缩

- 最好开启LZ4压缩。
- 压缩配置，Producer 端压缩、Broker 端保持、Consumer 端解压缩。

#### 提交策略

- 设置 acks = master。代表master Broker 收到消息，消息就算“已提交”。 
- 设置 acks = all。 代表所有副本Broker 都接收到消息，该消息才算是“已提交”。

#### 重试次数

设置 retries 为一个较大的值 比如3

#### 提交的方法

使用 producer.send(msg, callback)，必须实现回调函数。



#### 幂等消息

- 幂等消息是 0.11.0.0 版本以后，引入的 
- 开启方法：设置enable.idempotence=ture
- 注意事项：
  - 只能保证单分区上的幂等性，且当 Producer 进程重启以后之后，这种幂等性保证就丧失了
  - 需要 **多分区，多会话**上的消息无重复，需要使用事务型Producer



#### 事务型 Producer

- 保证一批消息原子性地写入到多个分区中，这批消息要么全部写入成功，要么全部失败。

- **开启方法**：

  - 配置 enable.idempotence=ture

  - 使用下面方法生产消息

    ```java
    //发送代码
    producer.initTransactions();
    try {
                producer.beginTransaction();
                producer.send(record1);
                producer.send(record2);
                producer.commitTransaction();
    } catch (KafkaException e) {
                producer.abortTransaction();
    }
    ```

  - **需要注意**，事务消息，在consumer端也要进行配置成 read_committed，表明 Consumer 只会消费 事务型 Producer 成功提交事务写入的消息。<br>Consumer 默认 read_uncommitted ， 表示消费者会消费所有消息，如果用了事务型 Producer，对应的 Consumer 就不要使用这个值，这是个坑。





## 消费者注意事项

### 基本原则

- 先实际消费，再提交位移。

- 默认先关闭自动提交 enable.auto.commit =  false ， 看场景选择是否打开。

- 必须配置消费者连接超时间， connection.max.idle.ms 

- 一个分区，只能被一个消费者消费。Consumer 实例的数量应该等于该 Group 订阅 Topic 的分区总数 。如果需要高可用，则 一个分区被两个消费者消费比较合理

  

### 独立消费者组

- Kafka Java Consumer 提供了一个名为 Standalone Consumer 的独立消费者类型。它没有消费者组的概念，每个消费者实例都是独立工作的，彼此之间毫无联系。

- 独立消费者，仍然需要配置 group.id 。且一旦独立消费者 与 其他group.id 重名，当独立消费者提交位移时，Kafka 就会立即抛出 CommitFailedException 异常，这已是一个坑，管理group.id 也是必要的。





### 提交

#### 自动提交

- 尽量不要使用，除非数据丢失无所谓，比如坐标点数据。

- enable.auto.commit = true 。 开启自动提交。

- auto.commit.interval.ms=5 。表明 Kafka 每 5 秒会为你自动提交一次位移

  

#### 手动提交范例

- 同步提交带重试功能 ，如果不需要高吞吐量，可以利用 commitSync 的自动重试来规避那些瞬时错误，比如网络的瞬时抖动

- 提交模板

```java
try {
    while (true) {
        ConsumerRecords<String, String> records = 
            consumer.poll(Duration.ofSeconds(1));
        process(records); // 处理消息
        commitAysnc(); // 使用异步提交规避阻塞
    }
} catch (Exception e) {
    handle(e); // 处理异常
} finally {
    try {
        consumer.commitSync(); // 最后一次提交使用同步阻塞式提交
    } finally {
        consumer.close();
    }
}
```



#### 精细管理位移

- Kafka Consumer API 还提供了一组更为方便的方法，可以帮助你实现更精细化的位移管理功能。

```java
commitSync(Map<TopicPartition, OffsetAndMetadata>) 
commitAsync(Map<TopicPartition, OffsetAndMetadata>)

private Map<TopicPartition, OffsetAndMetadata> offsets = new HashMap<>();
int count = 0;
……
……  
while (true) {
    ConsumerRecords<String, String> records = consumer.poll(Duration.ofSeconds(1));
    for (ConsumerRecord<String, String> record: records) {
        process(record);  // 处理消息
        offsets.put(new TopicPartition(record.topic(), record.partition()),
                    new OffsetAndMetadata(record.offset() + 1); 
        if（count % 100 == 0）{
            consumer.commitAsync(offsets, null); // 回调处理逻辑是 null
        }
                    
        count++;
    }
}
```



### **防止不必要rebalance**

消费者重平衡，是我们最经常遇到的问题。这里罗列一下常见的原因，尽量避免。

- **心跳超时**会导致 Consumer 被 “踢出” Group 

- **消费时间过长** 会导致 Consumer 被 “踢出” Group 

- **频繁的 Full GC 导致的长时间停顿**，引发了 Rebalance，这个在高吞吐量的时候，也比较很常见。<br>需要联合gc情况一起排查。

- **总结**：

  - session.timeout.ms = 7s 

    heartbeat.interval.ms = 2s。

    解释：要保证 Consumer 实例在被判定为“dead”之前，能够发送至少 3 轮的心跳请求，即 session.timeout.ms >= 3 * heartbeat.interval.ms。

  -  设置 max.poll.interval.ms  消费时长，根据业务的消费速度，预留充足的超时时间。





## 消费者最佳实践



### 消费者原则

1. 缩短单条消息处理的时间。
2. 减少下游系统一次性消费的消息总数。
3. 消费系统使用多线程来加速消费。（**最好方法**）
4. KafkaConsumer 类线程不安全，在多个线程中共享时，会抛 ConcurrentModificationException
5. 消费者启动多线程，n个Consumer对应n个线程，根据业务模式选择同步消费还是异步消费。

**选型**

- 方案一：多consumer + 相同线程消费。

```java
public class KafkaConsumerRunner implements Runnable {
     private final AtomicBoolean closed = new AtomicBoolean(false);
     private final KafkaConsumer consumer;
 
     public void run() {
         try {
             consumer.subscribe(Arrays.asList("topic"));
             while (!closed.get()) {
			ConsumerRecords records = 
				consumer.poll(Duration.ofMillis(10000));
                 //  执行消息处理逻辑
             }
         } catch (WakeupException e) {
             // Ignore exception if closing
             if (!closed.get()) throw e;
         } finally {
             consumer.close();
         }
     }
 
     // Shutdown hook which can be called from a separate thread
     public void shutdown() {
         closed.set(true);
         consumer.wakeup();
     }
}
```



- 方案二：单consumer + 多线程消费。

```java
private final KafkaConsumer<String, String> consumer;
private ExecutorService executors;
...
 
private int workerNum = ...;
executors = new ThreadPoolExecutor(
	workerNum, workerNum, 0L, TimeUnit.MILLISECONDS,
	new ArrayBlockingQueue<>(1000), 
	new ThreadPoolExecutor.CallerRunsPolicy());
 
 
...
while (true)  {
	ConsumerRecords<String, String> records = 
		consumer.poll(Duration.ofSeconds(1));
	for (final ConsumerRecord record : records) {
		executors.submit(new Worker(record));
	}
}
..
```



## kafa拦截器

Kafka 拦截器最低版本是0.10.0.0 。



### 生产者拦截器

#### 实现方法

`implement org.apache.kafka.clients.producer.ProducerInterceptor`

https://github.com/apache/kafka/blob/1a7ad70f24a1fa6b1640c2f768457324bbcda0df/clients/src/main/java/org/apache/kafka/clients/producer/ProducerInterceptor.java

- onSend：该方法会在消息发送之前被调用。如果想在发送之前对消息“美美容”，可以使用此方法

- onAcknowledgement：该方法会在消息成功提交或发送失败之后被调用。

  onAcknowledgement 的调用要早于 callback 的调用。

#### **备注**：

- 两个方法不是在同一个线程中被调用的，如果两个方法中调用了某个共享可变对象，要保证线程安全
- 不能阻塞，别放一些太重的逻辑进去，否则你会发现你的 Producer TPS 直线下降



### 消费者拦截器

#### 实现方法

`implement org.apache.kafka.clients.consumer.ConsumerInterceptor `

https://github.com/apache/kafka/blob/1a7ad70f24a1fa6b1640c2f768457324bbcda0df/clients/src/main/java/org/apache/kafka/clients/consumer/ConsumerInterceptor.java

- onConsume：该方法在消息返回给 Consumer 程序之前调用。在开始正式处理消息之前，

  拦截器会先拦一道，搞一些事情，之后再返回给你。

- onCommit：Consumer 在提交位移之后调用该方法。通常在该方法中做一些审计类业务

  比如打日志，统计等。

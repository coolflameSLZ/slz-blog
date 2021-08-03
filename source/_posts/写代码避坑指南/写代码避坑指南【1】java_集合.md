---
title: 写代码避坑指南【1】java_集合
toc: true
categories:
  - 写代码避坑指南
  - java
tags:
  - java
  - 实用开发小抄

hide: false
sortn: 10
date: 2021-08-03 01:27:34
---



java集合类，避坑指南。背了这么原理和实现，你真的能用对么？远离八股文工程师！

<!-- more -->

------



## 写java避坑指南【1】有关collect包

多线程中，使用线程不安全的容器，后果不仅仅是数据不对，还可能导致程序死循环。<br>**不要无脑使用 线程不安全 容器**。



### Map

#### 线程不安全

- HashMap，中规中矩，默认使用。
- Treemap，实现了SortedMap，放入的Key必须实现`Comparable`接口，有key排序首选使用。
- EnumMap，如果作为key的对象是enum类型，首选使用，效率很高。
- web开发中也需要空的 Map。使用`Map<K, V> emptyMap()`
- LinkedHashMap，要求key按照，put顺序存储时使用。
- IdentityHashMap，kv的查找关系不是equals，而是==。即java的地址查找，只有序列化框架可能会用到，业务开发一般用不到。



#### 线程安全

- concurrenthashmap，中规中矩，默认使用。但他的get、size 等方法没有用到锁，有可能获得旧的数据。

- hashtable，当必须保证强一致性时使用。

- concurrentSkipListMap，超大数据量(万级别)时候使用，且存在大量增删改操作的时候使用，在高并发下，跳表性能表现反超 concurrenthashmap。（红黑树在并发情况下，删除和插入过程中有个平衡的过程，锁竞争度会升高几个级别）

  


### map的使用注意事项

- 强制，k一定使用字符串，不允许用对象。（和equals方法有关，不展开）
- 默认，kv都尽量不允许为null。并发容器，k一定不允许为null，可能报npe不说，主要是没有意义。

| 集合类                | key<br>是否为null | value<br>是否为null | 是否线程安全 |
| --------------------- | ----------------- | ------------------- | ------------ |
| HashMap               | 允许l             | 允许                | 否           |
| TreeMap               | 不允许            | 允许                | 否           |
| LinkedHashMap         | 允许              | 允许                | 否           |
| EnumMap               | 不允许            | 允许                | 否           |
|                       |                   |                     |              |
| HashTable             | 不允许            | 不允许              | 是           |
| ConcurrentHashMap     | 不允许            | 不允许              | 是           |
| ConcurrentSkipListMap | 不允许            | 不允许              | 是           |



------



### List



#### 线程不安全

- 默认情况下一律使用ArrayList
- 有去重需要，默认使用HashSet
- 去重 + 重新排序 使用TreeSet。
- web开发中经常需要空 List。使用 `Collections.emptyList();`
- LinkedList，随机读性能很烂，业务开发没有使用场景，不建议使用



#### 线程安全

- 线程安全List，首选 `Colletcions.synchronizedList(new ArrayList<>());` 各方面都没有问题。
- 线程安全Set，JDK没有提供，可以使用hutool实现的 [线程安全的HashSet-ConcurrentHashSet](https://www.hutool.cn/docs/#/core/集合类/线程安全的HashSet-ConcurrentHashSet?id=线程安全的hashset-concurrenthashset)
- 线程安全的队列，使用hutool实现的，[有界优先队列-BoundedPriorityQueue](https://www.hutool.cn/docs/#/core/集合类/有界优先队列-BoundedPriorityQueue?id=有界优先队列-boundedpriorityqueue)
- DelayQueue 延时队列，阻塞的，一般情况下不会使用，非要使用，切记不能使用纳秒为单位。<br>（纳秒会让cpu负载上升几个数量将）
- CopyOnWriteArrayList 并发版ArrayList，这个容器写成本非常高，一般没有使用场景，如需并发写，ArrayList加锁即可。



### List的使用注意事项

| 集合类               | value<br/>是否为null | 是否线程安全 |
| -------------------- | -------------------- | ------------ |
| ArrayList            | 允许                 | 否           |
| HashSet              | 允许                 | 否           |
| TreeSet              | 不允许               | 否           |
| LinkedList           | 允许                 | 否           |
|                      |                      |              |
| HashTable            | 允许                 | 是           |
| ConcurrentHashSet    | 允许                 | 是           |
| BoundedPriorityQueue | 允许                 | 是           |
| DelayQueue           | 允许                 | 是           |
| CopyOnWriteArrayList | 允许                 | 是           |


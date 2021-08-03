---
title: java【1】集合类
toc: true
categories:
  - 写代码避坑指南
  - java
tags:
  - java
  - 实用开发小抄
hide: false
sortn: 20
date: 2021-08-04 02:08:33
---

java集合类，避坑指南。背了这么原理和实现，你真的能用对么？远离八股文工程师！

<!-- more -->

------



# 写java避坑指南：集合类



## Map

### map的选择

多线程中，使用线程不安全的容器，后果不仅仅是数据不对，还可能导致程序死循环。<br>**不要无脑使用 线程不安全 容器**。

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

  

#### map的使用注意事项

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

- ConcurrentHashMap 使用指南<br>size、isEmpty 和 containsValue 等传统API，在并发下会反映的中间状态，<br>需要使用原子操作api，优先使用原子性API，比如computeIfAbsent / putIfAbsent

  

------



## List



### List的选择



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

- Arrays.asList 返回的 List 不支持增删操作，会抛出UnsupportedOperationException异常
- 对数组的操作，切记是引用操作。所以对 List修改，会直接影响原始的数组。
- List.subList 返回的子List 不是一个新的ArrayList。是原ArrayList的一部分引用。

```java
// 构造新的List，在构造方法传入 SubList，来构建一个独立的 ArrayList;
List<Integer> subList = new ArrayList<>(list.subList(1, 4));
// 使用 Java8_Stream 的skip和limit来跳过流中的元素，同样可以达到 SubList 切片的目的。
List<Integer> subList = list.stream()
  .skip(1)
  .limit(3)
  .collect(Collectors.toList());
```

- 要对大 List 进行单值搜索的话，要把List转化成HashMap，其中 Key 是要搜索的值，Value 是原始对象List 的搜索复杂度。即使调用List.Search也要达到O(Logn)，HashMap则是O(1)。
- 对大List 进行区间搜索的话，提前把 HashMap 按照条件区间进行groupBy分组， Key 就是不同的区间。
- 存储同样的数据, HashMap消耗的内存是List的3倍, ArrayList 在内存占用  77% 是实际的数据, 而 HashMap 只有 22%，在内存特别紧张的情况线下，同样也可以考虑使用 List 的查找。





## 常见其他数据集合的坑



#### ArrayList 和 LinkedList

- 在各种常用场景下，LinkedList 几乎都不能在性能上胜出 ArrayList

  LinkedList 的作者 Josh Bloch说， 虽然 LinkedList 是我写的但我从来不用，有谁会真的用吗

|            | 随机访问 | 头节点访问 | 随机插入 | 头节点插入 |
| ---------- | -------- | ---------- | -------- | ---------- |
| ArrayList  | O(1)     | O(1)       | O(n)     | O(n)       |
| Linkedlist | O(n)     | O(1)       | O(n)     | O(1)       |

- 由于 CPU 缓存、内存连续性等问题，链表这种数据结构的实现方式对性能并不友好，即使在它最擅长的场景都不一定可以发挥威力。

- 在真实场景中，读写增删一般是平衡的，而且增删不可能只是对头尾对象进行操作，可能在 90% 的情况下都得不到性能增益，建议使用之前通过性能测试评估一下。






#### 使用WeakHashMap不当，导致OOM

- 使用 WeakHashMap 作为缓存容器：

  WeakHashMap 的 Key 在哈希表内部是弱引用的，当没有强引用指向这个 Key 之 后，key 和 value 会被 GC，这样就借助了jvm的垃圾回收器来帮我们实现缓存。

- 错误用法， value 中持有了 key的引用，导致 key永远不会被回收。

```java
public class xxx {

    // 错误， UserProfile 中持有 user， 而user正是key。这时， cache 永远不会回收。
    private Map<User, UserProfile> cache = new WeakHashMap<>();

    @GetMapping("wrong")
    public void wrong() {
        String userName = "zhuye";
        Executors.newSingleThreadScheduledExecutor().scheduleAtFixedRate(
                () -> log.info("cache size:{}", cache.size()), 1, 1, TimeUnit.SECONDS);
        LongStream.rangeClosed(1, 2000000).forEach(i -> {
            User user = new User(userName + i);
            cache.put(user, new UserProfile(user, "location" + i));
        });
    }
}

```

- 正确的用法

```java
public class xxx {


    // 用new WeakReference 包装一下value。 
    private Map<User, UserProfile> cache = new WeakHashMap<>();
    private Map<User, WeakReference<UserProfile>> cache2 = new WeakHashMap<>();

    @GetMapping("right")
    public void right() {
        String userName = "zhuye";
        Executors.newSingleThreadScheduledExecutor().scheduleAtFixedRate(
                () -> log.info("cache size:{}", cache2.size()), 1, 1, TimeUnit.SECONDS);
        LongStream.rangeClosed(1, 2000000).forEach(i -> {
            User user = new User(userName + i);
            cache2.put(user, new WeakReference(new UserProfile(user, "location" + i)));
        });
    }
    // 使用ConcurrentReferenceHashMap 可以解决这个问题
    private Map<User, UserProfile> cache3 = new ConcurrentReferenceHashMap<>();
    @GetMapping("right3")
    public void right3() {
        String userName = "zhuye";
        Executors.newSingleThreadScheduledExecutor().scheduleAtFixedRate(
                () -> log.info("cache size:{}", cache3.size()), 1, 1, TimeUnit.SECONDS);
        LongStream.rangeClosed(1, 20000000).forEach(i -> {
            User user = new User(userName + i);
            cache3.put(user, new UserProfile(user, "location" + i));
        });
    }
}
```






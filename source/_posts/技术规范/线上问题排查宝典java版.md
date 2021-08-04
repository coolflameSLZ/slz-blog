---
title: 线上问题排查宝典java版
toc: true
categories:
  - 技术规范

tags:
  - 技术规范
  - 运维
hide: false
date: 2021-08-05 00:01:47
---

线上有问题，不要急着跑路。先试试这本秘籍，无需自宫，轻松超神。
<!-- more -->

------



# 常见后端排错宝典



## 测试环境

测试环境可以使用远程断点、 Arthas、等附加进程进行排错。

测试环境也允许造数据，制造压力场景。



## 生产环境

1. 线上服务，保留现场回滚，首先进行恢复，回滚。有条件最好能留一个节点，屏蔽流量，作为现场。

   ```shell
   $ > jstack pid > jstack.log
   $ > jmap -dump:format=b,file=heap.log pid
   重启
   ```

2. 花5分钟，想想最近做了什么。问问别人，有什么变动。

3. 如果不紧急，比如mis后台，可以先申请暂停使用，尽量不要超过40分钟。

4. 通过日志，监控，快照，arthas进行分析。

   

## 工具：Arthas 快速下载

- 墙裂建议，将arthas 打到镜像里，紧急时候有大用
- 神器：https://arthas.aliyun.com/doc/
- `wget https://arthas.aliyun.com/arthas-boot.jar;java -jar arthas-boot.jar`
- 命令列表https://arthas.aliyun.com/doc/commands.html



## 常见问题解决思路



## CPU



### 排查流程

使用 top、vmstat、pidstat、ps 等工具排查

1. $`top`：找到cpu100%的Pid。

2. $`top -Hp 进程号`：查看java进程下的所有线程占CPU的情况。

3. $`printf "%x\n" 线程ID`： 后面查看线程都需要16进制数。<br>例如，printf "%x\n" 线程ID ，打印：16b1，那么在jstack中线程号就是16b1

4. $ `jstack 进程号 | grep 线程ID` ：通过jstack查看某一个线程。nid表示那个线程的状态。<br>例如`"VM Thread" os_prio=0 tid=0x00007f871806e000 nid=0x16b1 runnable`，<br>线程名=VM Thread，线程id=0x16b1，线程状态=runnable

5. $`jstat -gcutil 进程号 统计间隔毫秒 统计次数（缺省代表一直统计）`，查看某进程GC持续变化情况，

   ```shell
   shell@Alicloud:~$ jstat -gcutil 1287 100 100
     S0     S1     E      O      M     CCS    YGC     YGCT    FGC    FGCT     GCT   
     0.00   0.00  58.86  60.00  98.26  96.89     93    0.409     3    0.265    0.674
     0.00   0.00  58.86  60.00  98.26  96.89     93    0.409     3    0.265    0.674
     0.00   0.00  58.86  60.00  98.26  96.89     93    0.409     3    0.265    0.674
     0.00   0.00  58.86  60.00  98.26  96.89     93    0.409     3    0.265    0.674
   ```

   如果FGC很大，且一直增大，可以确认Full GC! 

   S0 S1 E 为新生代，O为老年代，M是元区间(方法区)
   YGC新生代执行次数，YGCT新生代执行时间
   FGC老年代执行次数，FGCT老年代执行时间
   GCT总垃圾回收时间（单位秒）
   
6. $`jmap -dump:format=b,file=dump_01.hprof pid`，导出某进程下内存heap输出到文件中。通过eclipse的mat工具查看内存中有哪些对象比较多。分析Full GC，<br>使用jmap要谨慎，尽量屏蔽掉流量，jmap是个重量级操作，容易卡死电脑。



### 使用 arthas 排查

- 查看CPU使用率top n线程的栈 `thread -n 3`

- 查找线程是否有阻塞`thread -b`

  

### 导致cpu高的常见原因

- hashmap，并发死循环
- Full GC次数过多，详见内存部分。
- 正则表达式非常消耗 CPU
- 分布式锁的重试机制
- 乐观锁、cas循环次数过多，或者竞争激烈
- Redis的端口6379被注入挖矿程序
- 突发压力，看看是不是攻击。查Nginx Access Log 



## 内存



### 排查流程

使用 free、top、ps、vmstat、cachestat、sar 等工具排查

1. $ `top -c` 输入大写M，以内存使用率从高到低排序。查看占用最高的pid。

2. $`jmap -histo pid` 和 $`jmap -histo:live pid` 先简单看看最耗内存的对象是谁

3. $`jmap -dump:format=b,file=dump_01.hprof pid`，导出某进程下内存heap输出到文件中。通过eclipse的mat工具查看内存中有哪些对象比较多。分析Full GC<br>使用jmap要谨慎，尽量屏蔽掉流量，jmap是个重量级操作，容易卡死电脑。

4. $`ls /proc/16818/fd |wc -l` ，查看进程打开的句柄数,

   $`ls /proc/16818/task |wc -l`，查看进程打开的线程数。

5.  使用 https://gceasy.io/ 快速查看GC分析报告

​	

### 内存占用高的常见原因

- 内存泄漏
  - 集合类中有对对象的引用，使用完后未清空，使得JVM不能回收。
  - 代码中存在死循环或循环产生过多重复的对象实体。
  - 使用的第三方软件中的BUG。
- 批量任务
- 缓存size过大，缓存命中率不高的时候，gc就会频繁清理缓存
- 序列化框架死循环，比如fastjson，gson。
- 启动参数内存值设定的过小。



## 网络

【todo】

### 排查流程

ping

tcpdump

Wireshark 分析 todo



### 网络连通性常见原因

内网DNS失效

负载均衡器失效





## 中间件问题

1. 先排查网络问题，中间件稳定性较高，没有特殊情况，本身不容易挂
2. 如果是私有化部署，排查那台机器有没有问题，可以通过运维平台看主机信息。
3. 排查组件进程基本情况，观察各种监控指标;
4. 查看组件的日志输出，特别是错误日志，中间件日志，尽量接入日志平台。
5. 进入组件控制台，使用一些命令查看其运作情况。



### mysql常见问题

- cpu高，查询没加索引，注意看看慢查询。

  

### redis常见问题



### kafka常见问题


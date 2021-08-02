---
title: mycat【5】使用技巧
toc: true
categories:
  - 数据库
  - mycat 
tags:
  - 中间件
  - 分库分表
  - mycat
hide: false
sortn: 50
date: 2021-08-01 14:52:13
---

mycat一些常见的使用技巧，和特殊sql语句

<!-- more -->

------



# mycat 使用技巧



## mycat 限制

**mycat 不适用的场景**

1. 需要大量使用，mycat禁用sql语句的场景
2. 经常需要跨分片关联查询的场景，ER分区表，全局表都不合适的时候。
3. 必须保证跨分片事物的强一致性的时候。



**mycat 不支持的sql语句**

1. `create table like XXX / create table select XXX`

2. 跨库（跨分片）多表关联查询，子查询

3. `select for update / select lock in share mode` ，

   悲观锁只会锁住一个数据节点，其他数据节点不加锁；并且加锁的时候，也不会抛出异常。

   可能会产生数据不一致。

4. 多表 update 更新 、update 分片键。update 分片键后可能会导致后面的查询找不到数据。

5. 跨分片update 、delete [order by] limit 。 mycat会在多个节点执行 limit语句，会造成数据删多了。

   

**mycat 的弱分布式事务**

使用的XA方式提交，但当所有事物ready之后，发送commit，此时有一个节点commit失败，则其他节点不会回滚。

所以 mycat 的XA事物只能支持到 ready 操作之前。

这种情况很难出现。



## mycat系统配置优化



### jvm参数优化

配置 /bin/startup_nowrap.sh



### server.xml 系统参数优化

| 值                   | 解释                                                 | 推荐值                       |
| -------------------- | ---------------------------------------------------- | ---------------------------- |
| frontWriteQueueSize  | 指定前端写队列的大小                                 | 2048                         |
| processors           | 系统可用线程的数量                                   | 根据cpu压力，一般是cpu数量*4 |
| processorBufferPool  | 指定所使用的ByteBuffer池的总字节容量，<br>单位为字节 | 2097152B                     |
| processorBufferChunk | 指定所使用的单个ByteBuffer的容量，<br>单位为字节     | 4096B                        |
| processorExecutor    | 每个processor的线程池大小                            | 16-64                        |



#### log4j2.xml 日志级别优化

修改日志级别就好，其他不用动

```xml
<asyncRoot level="info" includeLocation="true">
```





## mycat-web性能监控工具

已经打好包，在dockerhub上。

```sh
docker run --name mycat-web -d -p 8082:8082 --restart=always coolflame/mycat-web  
```

访问地址：

http://localhost:8082/mycat/



## mycat常用sql语句

使用 ` mysql -u[username] -p -P[管理端口，默认9066] -h[ip]`连接MyCat命令行管理端

```mysql
-- 常用:
# sql统计: 高频sql
show @@sql.high;
# sql统计: 大返回值
show @@sql.resultset  ;
# sql统计: 慢查询
show @@sql.slow  ;
# 线程池状态
show @@threadpool ;

-- 不常用:
#连接信息
show @@connection 
#后端库信息
show @@datasource;
#非堆内存使用情况
show @@directmemory=1;
#心跳情况
show @@heartbeat ;
#活动线程情况
show @@processor;
#mycat 服务器情况,主要是内存使用
show @@server;
```



## 使用MyCat生成执行SQL记录

在server.xml的system标签下配置拦截

```xml
<system>
  <!-- 配置拦截器 -->
  <property name="sqlInterceptor">
    io.mycat.server.interceptor.impl.StatisticsSqlInterceptor
  </property>
  <!-- 配置拦截SQL类型 -->
  <property name="sqlInterceptorType">
    select，update，insert，delete
  </property>
  <!-- 配置SQL生成文件位置 -->
  <property name="sqlInterceptorFile">
    /opt/mycat/InterceptorFile/sql.txt
  </property>
</system>
```

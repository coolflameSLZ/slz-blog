---
title: java【3】数据访问篇
toc: true
categories:
  - 写代码避坑指南
  - java
tags:
  - java
  - 实用开发小抄
hide: true
sortn: 30
date: 2021-08-06 00:50:12
---

背了这么原理和实现，你真的能用对么？背八股文一时爽，实战才能超神， show you the code now。
<!-- more -->

------



# 写java避坑指南：数据访问篇



## mybatis



### 缓存脏数据问题

- 一级缓存的脏数据问题
  - mybatis默认的一级缓存，作用域是 sqlsession，多 sqlsession 对数据进行修改，会产生脏数据问题。

- 二级缓存的脏数据问题
  - 二级缓存的作用域是数据库表，因此在多表查询时候，有可能会出现脏数据。
  - 二级缓存为本地缓存，分布式多节点部署的情况下，也可能出现脏数据。

- 总结
  - 建议关闭一二级缓存。
  - 如果有缓存需求，建议使用 spring cache + guava，或者redis。自己控制缓存的生命周期和一致性，其实不麻烦，也更香。


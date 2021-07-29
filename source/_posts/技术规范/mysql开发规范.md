---
title: mysql开发规范
date: 2021-07-27 22:53:44
toc: true 

excerpt: 可以落地的mysql使用规范

categories:
- 后端

tags:
- mysql
- 技术规范
- 设计
---

------



[TOC]



## **建表规范**



1. 默认使用使用innoDB 引擎，字符集 utf8mb4
2. 表名称规范<br>`[biz]_xxxx_[app|mis]_conf` : 在线、离线服务配置。 <br>`[biz]_xxxx_record` : 数据表，最高优先级。<br>`[biz]_xxxx_[app|mis]log` : 日志表，低优先级
3. 所有字段 NOT NULL ，优先设置 unsigned，小数设置为decimal，金额存成分，时间设置为datatime
4. 字段最大长度，保存克制，防止建索引时空间不够。
5. 字段长度大于1024需要拆分表，使用text， 主表上存拆分表id。
6. 表示 “是否” 字段，一律使用 if_xxx 的方式命名，数据类型是unsigned tinyint
7. 日增10万，年增5000万，id使用bigint，雪花算法。其余情况使用integer自增主键
8. 字段顺序依次为：主键、业务主键、状态、各种外键、各种分类、具体props、base属性… <br>正确示例：id，order_id，order_status，product_id，user_id，order_time
9. 保留名称，show、update、desc、status、range、match、delayed
10. 推荐：单表最大长度小于2000万，单行长度小于16Kb，单表小于2g





## **索引规范**

1. 联合索引的字段数目不能超过5，单表索引数量也不能超过5，索引设计遵循B+ Tree最左前匹配原则

2. 对一个VARCHAR(N)列创建索引时，通常取其50%（甚至更小）左右长度创建前缀索引就足以满足80%以上的查询需求了，没必要创建整列的全长度索引  

3. 根据业务命名空间的顺序构造联合索引，比如 productId/userId/serviceId/time/xxx

4. order by ， group by 的字段需要建立索引，尽量不使用groupby，orderby 使用java进程完成此操作

5. 业务上的全局唯一字段，需要建立唯一索引

6. 事物中，如 SELECT * FROM yes WHERE name ='yes' FOR UPDATE; <br>通过等普通条件判断【name = xxx】进行筛选加锁时，则该列（name）需要加索引。否则容易锁表。






## **SQL开发规范**

1. 对于 java 程序，只能使用 sql 模板查询，不允许使用各类动态sql生成器。

2. 强烈推荐：只使用 mybatis_code_helper_pro 生成 xml sql 语句。

3. 对外在线接口：<br>使用短sql，禁止三个表 join，禁止 where 子句，禁止 sql 函数。<br>对外接口尽量避免复杂查询，查询首先保证拓展性。

4. 推荐：使用mysql执行计划验收sql语句，注意索引的有序性，尽量使用覆盖索引。

5. 事务避免本类调用，使用hutool，SpringUtil获取事务方法。<br>直接使用传统 commit 指令也是不错的选择。

6. 超过10万行数据，首先确定分页的必要性；能否转换为下拉查询，或时间查询。<br>必须精确分页的话，查询使用 inner join

   ```sql
   select * from tables inner join
   ( select id from tables where [条件]  order by xxx limie 10000,10 )
   using id;
   ```





##  **分库分表后查询规范**

- 禁用语句


1. 分表后尽量只查询，或者根据 id update，避免范围修改，严禁莽撞的跨区修改。
2. 禁止，子查询，group by，order by
3. 禁止，悲观锁，使用Redisson替代数据库悲观锁（尽量使用无锁方法处理业务逻辑）。
4. 禁止，update sharding-key。update 分片键后可能会导致后面的查询找不到数据。
5. 禁止，跨区 update 、delete [order by] limit 。 mycat会在多个节点执行 limit语句，造成过多删除。


---
title: mysql开发规范
date: 2021-07-27 22:53:44
toc: true 

categories:
- 技术规范

tags:
- mysql
- 技术规范
- 设计

hide: false
---



http设计规范，设计接口后，可以对照自查表自省一下。

<!-- more -->

------



## **建表规范**



1. 默认使用使用innoDB 引擎，字符集 utf8mb4
2. 表名称规范<br>`[biz]_xxxx_[app|mis]_conf` : 在线、离线服务配置。 <br>`[biz]_xxxx_record` : 数据表，最高优先级。<br>`[biz]_xxxx_[app|mis]log` : 日志表，低优先级
3. 所有字段 NOT NULL ，整数字段考虑设置 unsigned
4. 字段最大长度，保持克制，防止建索引时空间不够。
5. 字段长度大于1024需要拆分表，使用text， 主表上存拆分表id。
7. 日增10万，年增3000万，id使用bigint，雪花算法，根据并发情况考虑分表。
8. 字段顺序依次为：主键、业务主键、状态、各种外键、各种分类、具体props、base属性… <br>正确示例：id，order_id，order_status，product_id，user_id，order_time<br>规范，保证代码可读性
9. 保留名称，show、update、desc、status、range、match、delayed...
10. 推荐：单表最大长度小于2000万，单行长度小于16Kb，单表小于2g
10. 常见字段类型

| 字段                        | 存储形式                  | 推荐索引                      | 解释                                                         |
| --------------------------- | ------------------------- | ----------------------------- | ------------------------------------------------------------ |
| 主键                        | bigint，雪花算法          | pk                            | 保持单调增                                                   |
| 业务id，<br>如oid，pid，uid | bigint，雪花算法+基因注入 | btree                         | 可以考虑以此为主键                                           |
| 一般小数                    | decimal                   | btree                         |                                                              |
| 金额                        | bigint，以分的形式存      | 一般没必要                    |                                                              |
| 电话号码                    | bigint，                  | 联合索引                      |                                                              |
| 业务时间                    | bigint                    | btree                         | 使用bigint，兼容性好<br>没有时区的坑，<br>性能也优秀         |
| 表示"是否"的列<br>if_xxx    | unsigned tinyint          | 不加索引，<br>有条件加bit索引 | if开头，避免java Bean的坑<br>mysql 没有bit索引，不加也罢<br>一律 0 false，1 true |



## **索引规范**

1. 联合索引的字段数目不能超过5，单表索引数量也不能超过5，索引设计遵循B+ Tree最左前匹配原则
2. 对一个VARCHAR(N)列创建索引时，通常取其50%（甚至更小）左右长度创建前缀索引就足以满足80%以上的查询需求了，没必要创建整列的全长度索引  
3. order by ， group by 的字段需要建立索引，尽量不使用groupby，orderby 使用java进程完成此操作
5. 业务上的全局唯一字段，需要建立唯一索引
6. 事物中，如 SELECT * FROM yes WHERE name = '张三' FOR UPDATE; <br>列（name）需要加索引，否则容易锁表。
7. 索引是要建在尽量不改动的字段上，频繁的变动索引列，对系统压力较大






## **SQL开发规范**

1. 对于 java 程序，只能使用 sql 模板查询，不允许使用各类动态sql生成器，<br>sql语句全部维护在 xml 文件中，方面管理，dba审查。sql往往才是一个后端程序的灵魂。

2. 强烈推荐：只使用 mybatis_code_helper_pro 生成 xml sql 语句，能避免sql类型转换的坑。

3. 上线前后，使用explain 跑一遍 xml中所有sql语句。type至少要到 range。

4. 对外在线接口：<br>使用短sql，禁止三个表 join，禁止 where 子句，禁止 sql 函数。<br>对外接口尽量避免复杂查询，查询首先保证拓展性。

5. 推荐：使用mysql执行计划验收sql语句，注意索引的有序性，尽量使用覆盖索引。

6. 事务避免本类调用事物方法，防止spring aop的坑；使用hutool中SpringUtil获取事务方法。<br>直接使用传统 `dataSourceTransactionManager.commit(transactionStatus)` 也是不错的选择，精细化控制事物。

7. 超过10万行数据，首先确定分页的必要性；能否转换为下拉查询，或时间查询。<br>必须精确分页的话，查询使用 inner join

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


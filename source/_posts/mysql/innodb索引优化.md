---
title: 'innodb索引优化'
toc: true
categories:
  - 数据库
  - mysql
tags:
  - innodb
hide: false
date: 2021-07-31 14:34:09
sortn: 20
---

本章主要介绍 innodb 引擎的大量数据索引优化

<!-- more -->

------



## 索引原理



### 聚簇索引

![img](https://cdn.jsdelivr.net/gh/coolflameSLZ/img/img20210731010412.png)

- 数据存储在主键索引中 
- 数据按主键顺序存储



### 二级索引

![image-20210731151934246](https://cdn.jsdelivr.net/gh/coolflameSLZ/img/img20210731151934.png)

- 除了主键索引以外的所有，都是二级索引

- 叶子中，存的是主键的值

- 一次查询，需要经过2次的查询操作，2logN 复杂度。

- 主键的大小，会影响索引的大小。

- 对于叶子节点，存【主键值】，还是存【数据地址】的取舍：

  innodb可能需要回表查询，即在聚簇索引中进一步查找对应的数据行。这样可以避免在行移动或者插入新数据时出现的页分裂问题。

  MyISAM中无论是主键索引还是二级索引，索引的叶子节点存放的都是指向数据行的指针，保证可以通过索引进而查找到对应的数据行，只需要对索引进行一遍查找。但这样会存在页分裂问题。

  

### 联合索引

![image-20210731153830652](https://cdn.jsdelivr.net/gh/coolflameSLZ/img/img20210731153830.png)

- 一个索引只创造1课树
- 假设有2列，就把量列拼接起来，(A:B) 形成一个长的组合索引
- 先通过A查找，找到后再通过B查找
- **总结：**
  - 如果不是按照最左开始查找，则无法使用索引，比如本例无法直接通过B查找
  - 如果是范围查找，则后面的列，无法使用索引。



## 索引优化分析



### 存储空间 （数据量与B+树的层高关系）

- 每个 page 都有一个 level，leaf page 的 level 是 0，root page 的 level 取决于整个 B+Tree 的高度。
- 因为页存储有 「空洞」 现象，所以不是非常固定的
- 一般来说 当数据为理论值的 2/3 时， 树就开始加一层了。

已知：

- Int 类型主键，每页可以存 1203 个子节点指针。

- bigint 类型主键，每页可以存 900 个子节点指针。

- 对于最下面一层的叶子节点：

  - 单行数据为 n byte ，每个page存 (16000  / n ) 条记录<br> 假如 1 行数据 300 byte，每个page 存 (16000  / n = 50）行数据。

  

**层高计算公式 ：**

**总行数 = （每页指针数） ^（几层）* 每页行数** 



当主键为 int (4 byte) 类型时，极限值为

| 高度     | 多少个<br/>索引页<br/>（非叶子） | 多少个<br/>数据页<br/>（叶子） | 每页能存<br>几个记录 | 得到的行数 | 数据大小大小 |
| -------- | -------------------------------- | ------------------------------ | -------------------- | ---------- | ------------ |
| 1（0+1） | 0                                | 1                              | 50                   | 50         | 16k          |
| 2（1+1） | 1                                | 1203                           | 50                   | 6万        | 18MB         |
| 3（2+1） | 1204                             | 1,447,209                      | 50                   | 7亿        | 22G          |
| 4（3+1） | 1,447,209                        | 17亿                           | 50                   | 850亿      | 25T          |



当主键为 bigint (8 byte) 类型时，极限值为

| 高度     | 多少个<br/>索引页<br/>（非叶子） | 多少个<br/>数据页<br/>（叶子） | 每页能存<br/>几个记录 | 得到的行数 | 数据大小大小 |
| -------- | -------------------------------- | ------------------------------ | --------------------- | ---------- | ------------ |
| 1（0+1） | 0                                | 1                              | 50                    | 50         | 16k          |
| 2（1+1） | 1                                | 928                            | 50                    | 46400      | 18MB         |
| 3（2+1） | 928                              | 861,184                        | 50                    | 4000万     | 22G          |
| 4（3+1） | 861,184                          | 8亿                            | 50                    | 40亿       | 25T          |

参考：https://blog.jcole.us/2013/01/10/btree-index-structures-in-innodb/



### 主键选择



- 自增主键

  - 顺序写入，效率高
  - 每次查询都走2级索引

- 随机主键

  - 节点分裂，数据移动，效率比较低
  - 有可能查询走2级索引

- 业务主键，比如订单号，用户id，商品id，等

  - 需要保证值是递增，一般情况下使用雪花算法即可
  - 写入，查询磁盘利用率都高，可以使用一级索引

- 联合主键

  - 影响索引列大小，不容易维护，不建议使用

  

### 联合索引使用



- 按索引区分度排序，区分度越高的放在前面。<br>比如主键，时间，外键，手机号，身份证号等。<br>索引区分度低的有，类型，状态等
- 覆盖索引，我们要查询的数据，正好在索引中，那么就不用回表了<br>比如一个索引 （id,phone,addr），在执行 `select phone，addr from user where id = 8;` 时<br>可以不用回表，直接返回结果集，又称三星索引。 
- 索引下推，mysql 5.6推出的性能改进，减少回表的次数，本该如此，不必细聊。



### 索引避坑指南



- 设置合理的长度

  - 前10个字符建索引就行，如果前10个字符都体现不出区分度，那么这个数据本身也有点问题<br>

  - 解决方案，对于区分度不大的列，再建立一个 hash 值列，通过索引（hash(addr),addr）查找就快了

    

- 索引失效的情况

  - A = XX or B=xx 索引会失效么？<br>不会失效，<br> mysql 5.1 引入了Index merge 技术，已经可以同时对 1个表使用多个索引分别扫描，1次出结果

    

  - 在联合索引中使用第二列，比如（phone，id_card_num）<br>使用`select * from user where id_card_num= 3701xxxxxx` 就不走索引

  

  - 隐式类型转换，不走索引<br>

    ```mysql
    -- type moblie Long
    -- 就不走索引
    select * from user where moblie= '186123232222'
    ```

    类型转换的时候，不使用索引。<br>上线前跑一遍查询计划，看看有没有这事，这个事很容易发生，但不容易发现。

    

  -  索引列包含计算，不走索引

    ```mysql
    select * from user where age-20 = 30;
    -- 没有人会这么干，如果有人这么干，必须请大家吃饭
    ```

    

  - 索引区分度低，有时候也不走索引<br>当索引的区分度过低，比如 sex ，if_old , sell_status 列，使用sql语句<br>`select * from user where sex=1 and phone=18678922342`<br>通过 sex 索引查询，要频繁的回表，这时候使用索引查询，还不如直接使用全表扫描更快。<br>

    

  - 查询条件，覆盖所有的索引值。也不会走本列索引<br>比如，有个 age 字段，使用sql语句，`select * from user where age < 200`<br>的时候，因为查询语句中的条件已经全部覆盖了整个数据集。<br>所以mysql也不会使用该索引。



### column类型最佳实践

- 数据库字符集使用 utf8mb4
- VARCHAR 按实际需要分配长度 ，255以上，需要更多的而空间描述长度，浪费空间
- 文本字段建议使用 VARCHAR
- 时间 字段使用 long，兼容性好，要不然迁移的时候，time类型有时区概念，容易出现bug
- bool字段使用tinyint
- 枚举字段建议使用 tinyint
- 交易金额 建议使用 long，存成分已足够，￥1.01存成 101
- 禁止使用 “%” 前导的查询
- 禁止在索引列进行数学运算，会导致索引失效



### 索引类型最佳实践

- 表必须有主键，建议使用业务主键，使用雪花算法保证自增。
- 单张表中索引数量不超过5个
- 单个索引字段数不超过5个
- 字符串索引使用前缀索引，前缀长度不超过10个字符




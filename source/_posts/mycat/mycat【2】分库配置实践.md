---
title: mycat【2】分库配置实践
toc: true
categories:
  - 数据库
  - mycat 
tags:
  - 中间件
  - 分库分表
  - mycat
hide: false
sortn: 20
date: 2021-08-01 13:56:48
---

本章主要讲了mycat 分库的配置，与实践套路

<!-- more -->

------



## mycat垂直切分



### 垂直分库步骤

1. #### 分析数据库依赖关系

   比如我们需要将订单表，用户表进行分库操作，master_db -> order_db , master_db -> user_db

   

2. #### 配置主从复制

   1. 备份原数据库并记录相关事务点（在主库中操作）

   ```shell
   # 数据导出，--master-data=2 --single-transaction 不能忘
   $ mysqldump --master-data=2 --single-transaction --routines --trigger --events -uroot -pxxxx master_db.sql > sub_master_db.sql
   
   # 数据导入
   $ mysql -uroot -pxxxx order_db < sub_master_db.sql
   
   ```

   2. 新建复制用户（在主库中操作，）

   ```mysql
   create user 'trans_user'@'192.168.1.%' identified by '[passward]' ;
   
   grant replication slave on *.* to 'trans_user'@'192.168.1.%';
   ```

   3. 在从库实例上恢复备份数据，并配置binlog 链路。

   ```mysql
   # 在从库中的配置主库地址
   change master to master_host ='192.168.1.x' , 
   master_user = 'trans_user' , 
   master_password = 'xxx' , 
   master_log_file = '[开始同步的日志文件名，这个值在备份文件中，MASTER_LOG_FILE = 'xxx']' ,
   master_log_pos = '[开始同步的事务点，这个值在备份文件中，MASTER_LOG_POS = 'xxx']' ;
   
   # 改写从库同步数据的数据库名称，主库中 master_db 在从库中则需要改写为 order_db 
   # 使用主从复制中的过滤函数 RELICATE_REWRITE
   filter replicate_rewrite_db = ((master_db,order_db))
   
   # 查询从库状态
   show slave status
   # 启动复制链路
   start slave
   
   # Slave_IO_Running, Slave_SQL_Running 状态为YES，则代表成功
   ```

   

3. #### 配置垂直分库逻辑

   通过中间件访问DB（垂直切分不需要配置 rule.xml）

   1. 假如主库需要分2个库，一个是order库，一个是user库。
   2. 配置 schema.xml ，配置顺序为：dataHost(2个) -> dataNode(2个) -> schema(1个)

   ```xml
   <?xml version="1.0"?>
   <!DOCTYPE mycat:schema SYSTEM "schema.dtd">
   <mycat:schema xmlns:mycat="http://io.mycat/">
          
       <!-- ③ 配置逻辑数据库中， table 与dataNode间关系-->
       <schema name="mall_db" checkSQLschema="true" sqlMaxLimit="100">
         <table name="order_detail" primarykey="id" dataNode="orderNode" ></table>
         <table name="order_account" primarykey="id" dataNode="orderNode" ></table>
         <table name="order_img" primarykey="id" dataNode="orderNode" ></table>
         <table name="user_address" primarykey="id" dataNode="userNode" ></table>
         <table name="user_info" primarykey="id" dataNode="userNode" ></table>
         <!-- 全局表，该表在所有的从库中都会有-->
         <table name="address" primarykey="id" dataNode="userNode,orderNode" type="global" ></table>
     	</schema>
      
       <!-- ② dataNode 数据库实例，与mysql实例映射-->
       <dataNode name="orderNode" dataHost="orderHost" database="order_db" />
       <dataNode name="userNode" dataHost="userHost" database="user_db" />
       
       <!-- ① dataHost mysql实例-->
   		<dataHost name="orderHost" maxCon="1000" minCon="10" balance="0" writeType="0" dbType="mysql" dbDriver="native" switchType="1"> 
         <heartbeat>select user()</heartbeat>
         <writeHost host="localhost" url="localhost:3307" user="order_db_user" password="123456" /> 
   		</dataHost>
     
     	<dataHost name="userHost" maxCon="1000" minCon="10" balance="0" writeType="0" dbType="mysql" dbDriver="native" switchType="1"> 
         <heartbeat>select user()</heartbeat>
         <writeHost host="localhost" url="localhost:3307" user="user_db_user" password="123456" /> 
   		</dataHost>
       
   </mycat:schema>
   ```

   2. 配置 server.xml 配置系统遍历及用户权限

   ```xml
   <user name="mall_user">
   		<property name="password">123456</property>
   		<property name="schemas">mall_db</property>
   </user>
   ```



4. #### 开始作案

   万事俱备后，夜黑风高之夜进行切换操作，需要预留足够的作案时间，回滚时间

   

5. #### 收尾

   删除原库中，的已迁移数据。从库中，多余的数据。

   1. 停止主从同步，stop slave;  reset slave all;  show status\g;
   2. 备份 ，drop表





## 水平切分

### 原则：

1. 能不切分就不切分。对于日志，历史记录这种大表，可以使用历史数据归档的方式进行数据转移，保证热点数据在数据库中即可。无法归档的数据时才考虑进行水平切分。
2. 选择合适的分片字段及分配规则，一定要提前想好，因为查询的时候也尽量需要带上分片键，这个后期修改困难
3. 尽量避免跨分片join



### 步骤

1. #### 确定分片键

   确定 分片表，分片键，分片算法，全局唯一id生成算法；记住要讨论一下有没有坑。

   **分片表**：将需要分片的表，以及频繁需要和分片表关联查询的表一起分片。（不经常使用join语句的话，可以忽略）

   **分片键**：主键id，业务唯一id（比如订单id），**外键或namespace**（比如订单关联的user_id,或者订单的日期, 订单的查询往往是以用户为单位查询，或者以时间为单位查询的，这一点需要考虑业务上的常用查询方式）

   **分片算法**：简单取模算法，哈希取模算法。

   

2. #### 配置 mycat 

   schema.xml

   ```xml
   <?xml version="1.0"?>
   <!DOCTYPE mycat:schema SYSTEM "schema.dtd">
   <mycat:schema xmlns:mycat="http://io.mycat/">
          
       <!-- ③ 配置逻辑数据库中， table 与dataNode间关系-->
       <schema name="order" checkSQLschema="true" sqlMaxLimit="100">
         <table name="order_master" primarykey="id" dataNode="orderNode0101,orderNode0102,orderNode0203,orderNode0204" rule="order_master" >
           <!-- ER分片表 -->
           <childTable name="order_detail" primaryKey="id" joinKey="id" parentKey="id" />
           
         </table>
     	</schema>
      
       <!-- ② dataNode 数据库实例，与mysql实例映射-->
       <dataNode name="orderNode0101" dataHost="orderHost01" database="order_db_01" />
       <dataNode name="orderNode0102" dataHost="orderHost01" database="order_db_02" />
       <dataNode name="orderNode0203" dataHost="orderHost02" database="order_db_03" />
       <dataNode name="orderNode0204" dataHost="orderHost02" database="order_db_04" />
       
       <!-- ① dataHost mysql实例-->
   		<dataHost name="orderHost01" maxCon="1000" minCon="10" balance="0" writeType="0" dbType="mysql" dbDriver="native" switchType="1"> 
         <heartbeat>select user()</heartbeat>
         <writeHost host="localhost" url="localhost:3307" user="order_db_user" password="123456" /> 
   		</dataHost>
     
     	<dataHost name="orderHost02" maxCon="1000" minCon="10" balance="0" writeType="0" dbType="mysql" dbDriver="native" switchType="1"> 
         <heartbeat>select user()</heartbeat>
         <writeHost host="localhost" url="localhost:3307" user="order_db_user" password="123456" /> 
   		</dataHost>
       
   </mycat:schema>
   ```

   rule.xml

   ```xml
   <mycat:rule xmlns:mycat="http://io.mycat/">
   	<tableRule name="order_mater">
   		<rule>
   			<columns>user_id</columns>
   			<algorithm>mod-long</algorithm>
   		</rule>
   	</tableRule>
   
   	<function name="mod-long" class="io.mycat.route.function.PartitionByMod">
   		<property name="count">4</property>
   	</function>
     
   </mycat:rule>
   ```

   server.xml

   ```xml
   <user name="mall_order">
   		<property name="password">123456</property>
   		<property name="schemas">order</property>
   </user>
   ```

   

3. 数据迁移，使用脚本，按照规定的分片算法进行数据迁移即可。


---
title: mycat【4】容器化
toc: true
categories:
  - 数据库
  - mycat 
tags:
  - 中间件
  - 分库分表
  - mycat
  - dockerfile

hide: false
date: 2021-08-01 12:43:59
sortn: 40
---

本章讲的是，mycat 具体实践的代码，小抄

<!-- more -->

------

# mycat容器化



## dockerfile

当前目录一览

```
.
├── Dockerfile
├── mycat-conf
│   ├── log4j2.xml
│   ├── rule.xml
│   ├── schema.xml
│   ├── server.xml
│   └── 此目录会覆盖 mycat/conf ，简略展示
└── mycat-server-1.6.7.5-release
    ├── bin
    ├── catlet
    ├── conf
    ├── lib
    ├── logs
    └── version.txt

```

Dockerfile

```dockerfile
FROM openjdk:8


# 标记mycat 版本号
ENV MYCAT_HOME=/app/mycat

# 添加 mycat - server
COPY ./mycat-server-1.6.7.5-release $MYCAT_HOME

# 添加 mycat 分库分表配置
COPY ./mycat-conf $MYCAT_HOME/conf

# 添加 mycat -class path
ENV PATH=$PATH:$MYCAT_HOME/bin

# 启动
# mycat 需要使用root
USER root
WORKDIR $MYCAT_HOME/bin
RUN chmod u+x ./mycat
EXPOSE 8066 9066
CMD ["./mycat","console"]
```



mycat 关键配置，

- rule.xml

- schema.xml

- server.xml

  

含数据库敏感信息，详见上文。




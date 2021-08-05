---
title: java【2】对象处理
toc: true
categories:
  - 写代码避坑指南
  - java
tags:
  - java
  - 实用开发小抄
hide: false
sortn: 20
date: 2021-08-05 02:08:33
---



背了这么原理和实现，你真的能用对么？背八股文一时爽，实战才能超神， show you the code now。
<!-- more -->

------





# 写java避坑指南：对象处理



## 等值问题



### 比较符选择

- **所有的判等**都需要用 objects.equals 判断，即使他们是基本类型。
- 明确需求，判断引用是否相等，才可以使用==



### hashCode 、 equals 、 compareTo

- 两个方法要配对实现，且要注意空指针问题。
- 如果要实现 compareTo ，必须保证 他和 equals 的逻辑一致性。

```java
//compareTo 不仅要比较大小，同样也会比较等于的情况。
//这是正确的例子
@Data
@AllArgsConstructor
static class StudentRight implements Comparable<StudentRight> {
    private int id;
    private String name;

    @Override
    public int compareTo(StudentRight other) {
        //  compare要包括所有的字段，
        //  不然会出现, 不该相等确相等的问题。
        return Comparator
                .comparingInt(StudentRight::getId)
                .thenComparing(StudentRight::getName)
                .compare(this, other);
    }
}
```



### lombok

@EqualsAndHashCode 默认实现没有使用父类属性，<br>使用 @EqualsAndHashCode(callSuper = true) 来支持父类字段



------



## NULL&空指针



### 空指针哲学

- 使用判空方式 或 Optional 方式来避免出现空指针异常，不一定是解决问题的最好方式，<br>空指针没出现可能隐藏了更深的 Bug，同样需要考虑为空的时候是应该出异常、设默认值、还是记录日志
- 业务系统最基本的标准是不能出现未处理的空指针异常，有条件的话建议订阅空指针异常报警，以便及时发现及时处理。



### 经常出现NullPointerException的几种场景

- 包装类型，自动拆箱
- 字符串，对象比较
- 容器类不支持存储null 的时候，比如ConcurrentHashMap 不支持Value为Null
- 级联调用不判空的时候
- 方法或远程服务返回的 List 不是空而是 null，不判空，直接调用 List 的方法出现空指针异常。



### 空指针排查

推荐使用线上诊断工具 Arthas 排查空指针，主要使用 watch 命令 和 stack命令 

https://alibaba.github.io/arthas/advanced-use.html#monitor-watch-trace



### java8 Optional

在Optional中，声明 orElse。无论值是否为空，orElse里面的方法都会执行一次。

所以，orElse中的方法，不能有副作用。

```java
public static void main(String[] args) {
		Integer getNumber = Optional.of(8).orElse(getNum());
}
private static Integer getNum() {
		System.out.println("getNum被调用了");
		return 0;
}
// 输出
getNum被调用了
最终getNumber=8
```



#### JSON，DTO 中的null

对于 JSON -> DTO 的过程，null 的表达歧义的，客户端不传某个属性，或者传null，这个属性在 DTO 中都是 null。<br>解决方案：使用 Optional 来包装，以区分客户端不传数据还是故意传 null。

```java
// UserDto 使用Optional包装，区分 不传值还是故意传null值
@Data
public class UserDto {
    private Long id;
    private Optional<String> name;
    private Optional<Integer> age;
}

@Data
public class UserEntity {
    @Id
    private Long id;
    @Column(nullable = false)
    private String name;
    @Column(nullable = false)
    private String nickname;
    @Column(nullable = false)
    private Integer age;
    @Column(nullable = false, columnDefinition = "TIMESTAMP DEFAULT CURRENT_TIMESTAMP")
    private Date createDate;
}

@PostMapping("right")
public UserEntity right(@RequestBody UserDto user) {
    if (user == null || user.getId() == null)
        throw new IllegalArgumentException("用户Id不能为空");

    UserEntity userEntity = userEntityRepository.findById(user.getId())
            .orElseThrow(() -> new IllegalArgumentException("用户不存在"));
		
    // 不传值会直接跳过31-33行
    if (user.getName() != null) {
      	// 传null值会执行34行
        userEntity.setName(user.getName().orElse(""));
    }
  
    userEntity.setNickname("guest" + userEntity.getName());
  
    if (user.getAge() != null) {
        userEntity.setAge(user.getAge().orElseThrow(() -> new IllegalArgumentException("年龄不能为空")));
    }
    return userEntityRepository.save(userEntity);
}
```



#### MySQL NULL 

MySQL 中 sum 函数没统计到任何记录时，会返回 null 而不是 0，可以使用 IFNULL 函数把 null 转换为 0

MySQL 中 count 字段不统计 null 值，COUNT(*) 才是统计所有记录数量的正确方式。

MySQL 中 对 NULL进行判断只能使用 IS NULL 或 者 IS NOT NULL。







------



## 对象转换问题



### 转换100M对象，一般会成倍使用内存空间。

数据库加载100M数据，但是 1GB 的 JVM 堆却无法完成导出操作，原因：

1. mysql record -> java entity  消耗了 200M；
2. 数据经过JDBC、Mybatis等框架，其实加载了2份数据，消耗了 200M * 2 ；
3. entity -> DTO 消耗了200M；

最终，占用的内存达到了 200M + 400M + 200M = 800M

**在进行容量评估时，我们不能认为一份数据在程序内存中也是一份，数据转换的时候，往往需要成倍的空间，即使将将满足，也会频繁Full GC。**

mybatis 大量返回集，请使用 流式查询语句。

```java
/** XXXmapper.java  **/
@Select("select * from t_iot where name = #{name} ")
@Options(resultSetType = ResultSetType.FORWARD_ONLY, fetchSize = 1024)
@ResultType(InfoPO.class)
void selectAutoList(@Param("name") String name,ResultHandler<InfoPO> handler);


/** 使用 **/
infoMapper.selectAutoList(name, resultContext -> {
  	resultContext.getResultObject();
  	// do something
});
```


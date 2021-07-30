---
title: API设计规范
toc: true

excerpt: http设计规范，无脑遵守就好

categories:
  - 后端

tags:
  - 设计
  - 技术规范

date: 2021-07-30 03:05:15
---



------





------



## API设计自查表



| 考虑点                                        | 结论 |
| :-------------------------------------------- | ---- |
| 接口命名                                      |      |
| 入参                                          |      |
| 出参                                          |      |
| header                                        |      |
| 包装结构体                                    |      |
| 版本                                          |      |
| 保障级别 （对内服务 or 对外服务 ｜ 使用人群） |      |
| 是否需要黑白名单，哪个位置加                  |      |
| 是否需要幂等，以及实现方案                    |      |
| 是否需要异步，以及实现方案                    |      |





------



## 详细解释



### 标准接口命名

- 范例：<br>`xxx/user/p0/v1/getuserInfo`<br>业务线 / 所属服务 / 保护级别 / 版本 / getuserInfo

- 禁止，PathVariable，不好管理，性能也有点问题<br>例如：/user/{user_id}

- 禁止，除了 get、post 以外的method，网关不好管理

- **保护级别**

  - p0: 主流程接口，对外服务核心流程，一般此类接口挂了，用户就会发现系统有问题。<br>需要全力保障的接口
  - p1: 非必要业务接口，一般是非核心查询接口，这类接口挂了，用户不容易察觉，<br>网关可以进行接口限流，根据user level 接口限流，也可以拿这类接口开刀。
  - p2: 信息采集类接口，可以不用保证可用性，后端也永远返回成功，<br>服务资源不足时候，网关可以直接下掉他们。

- 版本号

  - 使用v1、v2即可

  

### header

- jwt

- 业务上下文，采集使用

  如 user_id，client_id，client_type，biz，version，user_level，addr 等

  按需添加

- 调用链，trace_id，span_id，

  一般由工具生成。



### 入参

- 对外服务公共参数

  - 防篡改签名
  - 加token

  

- 对内服务公共参数

  - user_id
  - biz_id
  - service_id



### 出参

- 类型

  强制使用 application/json 类型，尽量为字符串类型。

  避免返回Long。

  

- 返回码

  业务异常、系统异常要分开。<br>业务异常保证无歧义，系统异常返回码为99999，降级使用。<br>确保多重状态，有不同的返回码，<br>例如，有一个接口叫"收单接口"，其内部调用"下单"接口。<br>收单服务正常的时候，下单接口可能返回失败。<br>设计接口结构时，状态码不能有歧义，"收单正常，下单失败" 与 "收单失败"  返回不同的状态码

  

- 包装结构

  错误返回：`{ code, msg, trace_id }`<br>正常返回：`{ code, msg, result: {} }` <br>分页返回：`{ code, msg, result: { recordList:[], page_info:{} } }`<br>**result 不允许为数组，默认为 空 {}，在java中使用 emptyMap 常量**

  

### 实现幂等的策略

- 唯一id + 时间字段。通过时间过滤后，使用trans_id 避免重复 （最通用的实现）

  可以加前置 缓存队列 ，进行专门的去重。

- 新增类接口，加唯一索引。（低并发下，实现最简单）

- 乐观锁字段。（效率最高，但大量并发时需要避免）

- 服务端发放提交票据，（两次交互，费时费力，不推荐）

- 状态机幂等， `set order_status = [done] ` 天生幂等 

效率优先：乐观锁 > 唯一约束 > 唯一索引



### 异步策略

例如**上传接口**

- 同步

```java
public SyncUploadResponse syncUpload(SyncUploadRequest request) {
  SyncUploadResponse response = new SyncUploadResponse();
  response.setDownloadUrl(uploadFile(request.getFile()));
  response.setThumbnailDownloadUrl(uploadThumbnailFile(request.getFile()));
  return response;
}
```

- 异步上传，立即返回一个任务id，客户端根据任务id轮询结果。

  

```java
//在接口实现上，我们同样把上传任务提交到线程池处理，但是并不会同步等待任务完成，而是完成后把结果写入一个 HashMap，任务查询接口通过查询这个 HashMap 来获得文件 的 URL
public class asyncDemo {

    //计数器，作为上传任务的ID
    private AtomicInteger atomicInteger = new AtomicInteger(0);
    //暂存上传操作的结果，生产代码需要考虑数据持久化
    private ConcurrentHashMap<String, SyncQueryUploadTaskResponse> downloadUrl = new ConcurrentHashMap<>();

    // 立即返回任务id
    public AsyncUploadResponse asyncUpload(AsyncUploadRequest request) {
        AsyncUploadResponse response = new AsyncUploadResponse();
        //生成唯一的上传任务ID
        String taskId = "upload" + atomicInteger.incrementAndGet
        //异步上传操作只返回任务ID
        response.setTaskId(taskId);
        //提交上传原始文件操作到线程池异步处理
        threadPool.execute(() -> {
            String url = uploadFile(request.getFile());
            //如果ConcurrentHashMap不包含Key，则初始化一个SyncQueryUploadTaskResponse
            downloadUrl.computeIfAbsent(taskId,
                    id -> new SyncQueryUploadTaskResponse(id)).setDownloadUrl(url);
        });

        //提交上传缩略图操作到线程池异步处理
        threadPool.execute(() -> {
            String url = uploadThumbnailFile(request.getFile());
            downloadUrl.computeIfAbsent(taskId,
                    id -> new SyncQueryUploadTaskResponse(id)).setThumbnailDownloadUrl(url);
        });
        return response;
    }

```


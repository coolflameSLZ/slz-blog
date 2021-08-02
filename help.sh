

# 指令教程： https://hexo.io/zh-cn/docs/commands

# fluid 教程：https://hexo.fluid-dev.com/docs/guide

# 新建文章
hexo new --path "消息系统/kafka【5】命令行工具" "kafka【5】命令行工具"


# 生成静态文件
hexo generate --deploy --force


# 清理缓存
hexo clean

# 打包发布
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
hexo clean
hexo g
hexo d



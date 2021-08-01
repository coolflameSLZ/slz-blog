

# 指令教程： https://hexo.io/zh-cn/docs/commands

# fluid 教程：https://hexo.fluid-dev.com/docs/guide

# 新建文章
hexo new --path "注册中心/注册中心的选型与设计" "注册中心的选型与设计"


# 生成静态文件
hexo generate --deploy --force


# 清理缓存
hexo clean

# 打包发布
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
hexo clean
hexo g
hexo d



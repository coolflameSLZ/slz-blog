# 指令教程： https://hexo.io/zh-cn/docs/commands

# 新建文章
hexo new --path "技术规范/mysql开发规范" "mysql开发规范"

# 新建草稿
hexo new draft --path "技术规范/API设计规范" "API设计规范"

# 生成静态文件
hexo generate --deploy --force


# 清理缓存
hexo clean

# 打包发布
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
hexo clean
hexo g
hexo d



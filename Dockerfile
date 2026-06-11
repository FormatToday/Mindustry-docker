# 第一阶段：下载最新的 Mindustry 服务端 JAR
FROM alpine:3.20 AS downloader

# 安装依赖（curl 用于 API 请求和下载，jq 用于解析 JSON）
RUN apk add --no-cache curl jq

# 设置工作目录
WORKDIR /download

# 从 GitHub API 获取最新正式版的 server.jar 下载链接并下载
# 排除预发布版本（prerelease=false），只取第一个匹配的 server.jar 资产
RUN curl -sSL https://api.github.com/repos/Anuken/Mindustry/releases/latest \
    | jq -r '.assets[] | select(.name == "Mindustry.jar") | .browser_download_url' \
    | xargs curl -sSL -o server.jar

# 验证文件是否下载成功
RUN if [ ! -f server.jar ]; then echo "下载失败！请检查网络连接或 GitHub API 访问权限"; exit 1; fi

# 第二阶段：运行服务端（使用官方 OpenJDK 17 镜像，Mindustry 要求 Java 17+）
FROM eclipse-temurin:17-jre-alpine

# 安装必要工具（tini 用于正确处理信号，避免僵尸进程）
RUN apk add --no-cache tini

# 创建非 root 用户运行服务，提高安全性
RUN addgroup -g 1000 mindustry && adduser -u 1000 -G mindustry -s /bin/sh -D mindustry

# 设置工作目录
WORKDIR /app

# 从下载阶段复制 JAR 文件
COPY --from=downloader --chown=mindustry:mindustry /download/server.jar .

# 暴露服务端口（TCP 用于游戏连接，UDP 用于查询和广播）
EXPOSE 6567/tcp 6567/udp

# 切换到非 root 用户
USER mindustry

# 设置入口点，使用 tini 启动 Java 进程
ENTRYPOINT ["/sbin/tini", "--", "java", "-jar", "server.jar"]

# 默认启动参数（可通过 docker-compose 覆盖）
CMD ["headless"]

# UModel 单镜像服务器部署实践

本目录用于把 UModel 打成一个可发布到服务器的单镜像，并在服务器上启动 API、Web UI 和 MCP。

目标：

- 一个镜像启动 UModel API、Web UI 和 HTTP MCP。
- GraphStore 使用 `local.ladybug`。
- 存储挂载到服务器本机目录。
- Web、API 和 MCP 端口分别暴露。

## 目录结构

```text
deployments/single-image/
  .env.example
  Makefile
  README.md
  compose/docker-compose.yaml
  runtime/Dockerfile
  runtime/entrypoint.sh
  runtime/nginx.conf
  scripts/build.sh
  scripts/health.sh
  scripts/logs.sh
  scripts/run.sh
  scripts/stop.sh
```

## 推荐部署形态

| 项目 | 推荐值 |
|---|---|
| 镜像名 | `umodel-ladybug:local` |
| API 容器端口 | `8080` |
| Web 容器端口 | `5173` |
| MCP 容器端口 | `8090` |
| 本地验证数据目录 | `.run/umodel-ladybug/data` |
| 服务器推荐数据目录 | `/srv/umodel/data` |
| 容器数据目录 | `/data` |
| GraphStore | `local.ladybug` |

运行时拓扑：

```text
Browser -> http://server:5173 -> Nginx static web
Browser -> http://server:5173/api/* -> Nginx -> UModel API :8080
Client  -> http://server:8080 -> UModel API :8080
Agent   -> http://server:8090/mcp -> UModel MCP :8090
UModel API -> /data -> host .run/umodel-ladybug/data
```

## 前置条件

```bash
go version
docker version
```

Ladybug 构建依赖 `github.com/LadybugDB/go-ladybug` 和 `liblbug` native runtime。本实践镜像会在 service-build 阶段通过 `go-ladybug v0.13.1` 的下载脚本获取 `liblbug`，用 `-tags "ladybug system_ladybug"` 编译，并把 native 库复制到最终 Nginx 镜像。

## 构建镜像

从 UModel 仓库根目录执行：

```bash
make -C deployments/single-image build
```

可覆盖镜像名：

```bash
UMODEL_IMAGE=registry.example.com/umodel-ladybug:20260606 \
make -C deployments/single-image build
```

脚本使用 [runtime/Dockerfile](runtime/Dockerfile)。镜像内包含：

- `umodel-server-mcp`，通过 `go build -tags "ladybug system_ladybug"` 构建，内置 MCP 挂载在 `/mcp/{workspace}`。
- `umodel-mcp`，通过同一组 Ladybug build tags 构建，默认以 Streamable HTTP 监听 `:8090`。
- `liblbug` native runtime，默认按 Docker 目标架构下载并复制到 `/usr/local/lib`。
- 最终镜像显式安装 `libstdc++6` 和 `libgomp1`，用于覆盖常见 C/C++ runtime 依赖。
- Web UI 静态文件，来自 `web` 的生产构建。
- Nginx，监听 `5173`，并把 `/api/*` 和 `/healthz` 代理到 API。
- [runtime/entrypoint.sh](runtime/entrypoint.sh)，同时启动 API、MCP 和 Nginx。

当前实践先打通 x86_64 流程，默认 `DOCKER_PLATFORM=linux/amd64`、`LADYBUG_ARCH=x86_64`。如果后续要构建 arm64，再手动覆盖：

```bash
DOCKER_PLATFORM=linux/arm64 \
LADYBUG_ARCH=aarch64 \
make -C deployments/single-image build
```

默认会按 `LADYBUG_VERSION`、`LADYBUG_OS` 和 `LADYBUG_ARCH` 拼出 Ladybug release asset 地址，例如 `https://github.com/LadybugDB/ladybug/releases/download/v0.13.1/liblbug-linux-aarch64.tar.gz`。如果 `liblbug` 下载地址不可访问，可以覆盖 `LADYBUG_DOWNLOAD_URL` 为内部制品库地址。

`liblbug v0.13.1` 依赖 `GLIBC_2.38` 和较新的 `GLIBCXX` 符号，服务构建阶段和最终运行镜像默认使用 Debian trixie 系列。不要把 `GOLANG_IMAGE` 或 `NGINX_IMAGE` 改回 bookworm，除非同时换成兼容 bookworm 的 `liblbug` 制品。

如果当前 shell 里 `docker` 不在 `PATH`，可以显式指定：

```bash
DOCKER_BIN=/opt/homebrew/bin/docker \
make -C deployments/single-image build
```

如果构建机访问 Docker Hub、GitHub、npm 或 Go proxy 需要代理：

```bash
export HTTPS_PROXY=http://127.0.0.1:7891
export HTTP_PROXY=http://127.0.0.1:7890
export NO_PROXY=localhost,127.0.0.1
make -C deployments/single-image build
```

脚本会把这些代理变量透传给 Docker build。基础镜像拉取仍依赖 Docker daemon/BuildKit 的网络配置；如果基础镜像 metadata 拉取仍失败，需要在 Docker Desktop 的 proxy 设置里配置同一组代理，或通过 `NODE_IMAGE`、`GOLANG_IMAGE`、`NGINX_IMAGE` 指向内部镜像仓库。

当代理地址使用 `127.0.0.1`、`localhost` 或 `[::1]` 时，脚本会在传给 Docker build 容器前自动改写为 `host.docker.internal`，避免容器内的 Corepack、pnpm、curl 或 Go 访问自己的 loopback 地址。

## 单容器启动

脚本会自动加载 `deployments/single-image/.env`。如果需要使用其他 env 文件，设置 `UMODEL_ENV_FILE=/path/to/env`；如果同名变量已经在当前 shell 中设置，shell 中的值优先。

默认配置按用途分组：

| 分组 | 环境变量 | 默认值 | 使用位置 |
|---|---|---|---|
| 镜像标识 | `UMODEL_IMAGE` | `umodel-ladybug:local` | `build.sh` 构建标签，`run.sh`/Compose 启动镜像 |
| 运行容器 | `UMODEL_CONTAINER` | `umodel` | `run.sh`、`stop.sh`、`logs.sh` |
| 运行容器 | `UMODEL_HOST_DATA` | `<repo>/.run/umodel-ladybug/data` | `run.sh`、Compose 挂载 `/data` |
| 运行容器 | `UMODEL_WEB_PORT` | `5173` | `run.sh`、`health.sh`、Compose 暴露 Web |
| 运行容器 | `UMODEL_API_PORT` | `8080` | `run.sh`、`health.sh`、Compose 暴露 API |
| 运行容器 | `UMODEL_MCP_PORT` | `8090` | `run.sh`、`health.sh`、Compose 暴露 MCP |
| 构建工具 | `DOCKER_BIN` | `docker` | 所有脚本调用 Docker |
| 构建工具 | `DOCKER_HELPER_PATH` | `/usr/local/bin:/Applications/Docker.app/Contents/Resources/bin:/opt/homebrew/bin` | 脚本查找 Docker CLI/helper |
| 构建目标 | `DOCKER_PLATFORM` | `linux/amd64` | `build.sh` 的 Docker build platform |
| 构建 Ladybug | `LADYBUG_VERSION` | `0.13.1` | `build.sh` 下载 `liblbug` 和定位 Go module |
| 构建 Ladybug | `LADYBUG_OS` | `linux` | `build.sh` 拼 native runtime 下载地址 |
| 构建 Ladybug | `LADYBUG_ARCH` | `x86_64` | `build.sh` 拼 native runtime 下载地址 |
| 构建 Ladybug | `LADYBUG_DOWNLOAD_URL` | empty, auto-build from version/os/arch | `build.sh` 覆盖 native runtime 下载地址 |
| 构建基础镜像 | `NODE_IMAGE` | `node:22-bookworm-slim` | `build.sh` Web 构建阶段 |
| 构建基础镜像 | `GOLANG_IMAGE` | `golang:1.25-trixie` | `build.sh` 服务构建阶段，需要满足 `liblbug` 的 GLIBC/GLIBCXX 版本 |
| 构建基础镜像 | `NGINX_IMAGE` | `nginx:1.29-trixie` | `build.sh` 最终运行镜像，需要满足 `liblbug` 的 GLIBC/GLIBCXX 版本 |

启动：

```bash
make -C deployments/single-image run
```

覆盖本机数据目录和端口：

```bash
UMODEL_HOST_DATA=/data/umodel \
UMODEL_WEB_PORT=18080 \
UMODEL_API_PORT=18081 \
UMODEL_MCP_PORT=18082 \
make -C deployments/single-image run
```

访问：

| 服务 | 地址 |
|---|---|
| Web UI | `http://<server-ip>:5173` |
| API | `http://<server-ip>:8080` |
| API health | `http://<server-ip>:8080/healthz` |
| Web 代理 health | `http://<server-ip>:5173/healthz` |
| MCP | `http://<server-ip>:8090/mcp` |
| MCP health | `http://<server-ip>:8090/healthz` |

检查：

```bash
make -C deployments/single-image health
make -C deployments/single-image logs
```

停止：

```bash
make -C deployments/single-image stop
```

## Compose 启动

可复制 [.env.example](.env.example) 为 `.env` 后修改：

```bash
cp deployments/single-image/.env.example deployments/single-image/.env
```

启动：

```bash
make -C deployments/single-image compose-up
```

查看日志：

```bash
make -C deployments/single-image compose-logs
```

停止：

```bash
make -C deployments/single-image compose-down
```

## 数据目录

`local.ladybug` 会把 workspace 元数据和图数据持久化到挂载目录。重启容器后，同一个数据目录会恢复已有 workspace 列表；如果 `/data/workspaces.json` 缺失，也会从 Ladybug 图数据目录恢复 workspace metadata。

```text
.run/umodel-ladybug/data/
  workspaces.json
  instances/<workspace>/storage/graph/local/ladybug/
```

不要让多个 UModel 容器同时写同一个主机数据目录。升级镜像前先备份这个目录。

## 边界说明

- 本实践不修改官方源码。
- 本实践不修改官方 Dockerfile 或 Compose。
- Web/API/MCP 分端口暴露，Web 通过独立镜像内的 Nginx 提供。
- API 通过 `umodel-server-mcp` 启动参数选择 `local.ladybug`。
- MCP 通过镜像内的 `umodel-mcp --transport http` 提供，默认 workspace 为 `demo`。

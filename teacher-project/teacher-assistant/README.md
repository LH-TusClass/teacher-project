# 教师助手（前后端分离版）

基于 Node.js(Express) + Vue3 + MySQL 8 + Redis 6 的教师学生管理平台。
原 JSON 文件存储（data/db.json）已迁移到 MySQL，不再通过 JSON 文件管理数据。

## 架构

| 组件 | 说明 | 监听 |
| --- | --- | --- |
| Nginx | 托管前端静态资源 + 反向代理 `/api` 到后端 | 0.0.0.0:80 |
| 前端 web/dist | Vue3 构建产物 | 由 Nginx 提供 |
| 后端 Express | 纯 API 服务（server/index.js） | 127.0.0.1:3210 |
| MySQL 8 | 业务数据库 teacher_assistant（utf8mb4） | 127.0.0.1:3306 |
| Redis 6 | 读缓存、缓存失效版本号、AI 限流与结果缓存 | 127.0.0.1:6379 |

## 目录

- `server/index.js` — API 路由（班级/学生/考试/成绩/抽奖/座位/AI 分析）
- `server/db.js` — MySQL 连接池
- `server/cache.js` — Redis 缓存与限流
- `server/schema.sql` — 数据库 DDL（唯一 schema 来源）
- `server/migrate.js` — 一次性迁移脚本（data/db.json → MySQL）
- `web/` — Vue3 前端源码（npm run build 产出 dist）
- `.env` — 环境变量（LLM/MySQL/Redis 配置，勿提交）

## 常用命令

```bash
systemctl restart teacher-assistant   # 重启后端
systemctl status mysqld redis nginx   # 查看服务状态
cd /opt/teacher-assistant && npm run build   # 重新构建前端
node server/migrate.js                # 重新导入 data 归档数据
```

## 环境变量（.env）

`DB_HOST / DB_PORT / DB_NAME / DB_USER / DB_PASSWORD` — MySQL
`REDIS_HOST / REDIS_PORT / REDIS_PASSWORD` — Redis
`LLM_API_KEY / LLM_BASE_URL / LLM_MODEL` — AI 分析模型
`PORT` — 后端端口（默认 3210）
`CORS_ORIGIN` — 允许的跨域来源（默认 *）

## Nginx 站点

配置文件：`/www/server/panel/vhost/nginx/teacher-assistant.conf`
（静态根目录 `web/dist`，`location /api/` 反代 127.0.0.1:3210，SPA 兜底 index.html）

# 🚀 Yearning Linux部署指南

## 方式1: 编译部署 (推荐)

```bash
# 1. 构建Linux版本
./build.sh

# 2. 配置数据库
cp conf.toml.template conf.toml
# 编辑 conf.toml 配置MySQL连接

# 3. 初始化
./Yearning install

# 4. 启动
./Yearning run
```

## 方式2: Docker部署

```bash
# 1. 启动
docker-compose -f docker-compose.prod.yml up -d

# 2. 初始化数据库
docker-compose -f docker-compose.prod.yml exec yearning ./Yearning install
```

## 配置说明

编辑 `conf.toml` 文件：
```toml
[Mysql]
Host = "你的MySQL地址"
Port = "3306"
User = "yearning"
Password = "你的密码"
Db = "yearning"
```

## 默认账号

- 用户名: `admin`
- 密码: `Yearning_admin`
- 地址: `http://你的服务器:8000`

就这么简单！🎉

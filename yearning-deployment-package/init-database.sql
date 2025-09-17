-- Yearning MySQL 5.7 生产环境初始化脚本

-- 创建数据库
CREATE DATABASE IF NOT EXISTS yearning CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 创建用户（本地和远程访问）
CREATE USER IF NOT EXISTS 'yearning'@'localhost' IDENTIFIED BY 'yearning_password_change_me';
CREATE USER IF NOT EXISTS 'yearning'@'%' IDENTIFIED BY 'yearning_password_change_me';
CREATE USER IF NOT EXISTS 'yearning'@'172.%.%.%' IDENTIFIED BY 'yearning_password_change_me';

-- 授权
GRANT ALL PRIVILEGES ON yearning.* TO 'yearning'@'localhost';
GRANT ALL PRIVILEGES ON yearning.* TO 'yearning'@'%';
GRANT ALL PRIVILEGES ON yearning.* TO 'yearning'@'172.%.%.%';

-- 刷新权限
FLUSH PRIVILEGES;

-- 验证用户创建
SELECT User, Host FROM mysql.user WHERE User = 'yearning';

-- 验证数据库创建
SHOW DATABASES LIKE 'yearning';
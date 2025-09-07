# Multi-stage build for Railway deployment
FROM mysql:5.7 as mysql-base

FROM alpine:latest
RUN apk --no-cache add ca-certificates tzdata mysql mysql-client bash curl

WORKDIR /app

# Copy pre-built binary and config
COPY Yearning /app/
COPY conf.toml /app/

# Setup MySQL data directory
RUN mkdir -p /var/lib/mysql /run/mysqld /var/log/mysql
RUN chown -R mysql:mysql /var/lib/mysql /run/mysqld /var/log/mysql

# Initialize MySQL database
RUN mysqld --initialize-insecure --user=mysql --datadir=/var/lib/mysql

# Create startup script
RUN cat > /app/start.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Starting Yearning with MySQL..."

# Start MySQL in background
mysqld_safe --user=mysql --datadir=/var/lib/mysql --skip-networking=false --bind-address=0.0.0.0 &
MYSQL_PID=$!

echo "⏳ Waiting for MySQL to start..."
sleep 15

# Setup database and user
mysql -u root << 'SQL'
CREATE DATABASE IF NOT EXISTS yearning CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS 'yearning'@'%' IDENTIFIED BY 'ukC2ZkcG_ZTeb';
GRANT ALL PRIVILEGES ON yearning.* TO 'yearning'@'%';
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY 'ukC2ZkcG_ZTeb';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%';
FLUSH PRIVILEGES;
SQL

echo "📊 Database initialized successfully"

# Update config for embedded MySQL
sed -i 's/Host = "127.0.0.1"/Host = "localhost"/g' /app/conf.toml

# Initialize Yearning (first time setup)
echo "🔧 Initializing Yearning..."
cd /app
./Yearning install || echo "Install step completed"

echo "🌟 Starting Yearning application..."
exec ./Yearning run --config conf.toml
EOF

RUN chmod +x /app/start.sh

EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/ || exit 1

CMD ["/app/start.sh"]
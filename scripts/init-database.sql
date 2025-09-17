-- Yearning SQL审计平台 - 数据库初始化脚本
-- 版本: v1.0.0
-- 作者: Yearning Team
-- 更新时间: 2025-09-17
-- 说明: 此脚本用于在Yearning安装后进行必要的数据初始化

-- ==========================================
-- 1. 创建管理员账户
-- ==========================================
-- 删除可能存在的旧数据
DELETE FROM core_accounts WHERE username = 'admin';

-- 创建管理员账户 (密码: Yearning_admin)
INSERT INTO core_accounts (username, password, department, real_name, email, is_recorder)
VALUES (
    'admin',
    'pbkdf2_sha256$120000$i6a87vzFbUNL$hhBpau/sh85lJ8S68XW0R41aOKEnOzCnl0UwfZ6xTps=',
    'DBA',
    '超级管理员',
    'admin@company.com',
    2
);

-- ==========================================
-- 2. 创建权限组
-- ==========================================
-- 生成随机UUID作为权限组ID
SET @group_uuid = UUID();

-- 删除可能存在的旧权限组
DELETE FROM core_role_groups WHERE name = 'DBA';

-- 创建DBA权限组（权限将在添加数据源后更新）
INSERT INTO core_role_groups (name, permissions, group_id)
VALUES (
    'DBA',
    '{"ddl_source": [], "dml_source": [], "query_source": []}',
    @group_uuid
);

-- ==========================================
-- 3. 关联用户和权限组
-- ==========================================
-- 删除可能存在的旧关联
DELETE FROM core_graineds WHERE username = 'admin';

-- 关联admin用户到DBA权限组
INSERT INTO core_graineds (username, `group`)
VALUES ('admin', CONCAT('["', @group_uuid, '"]'));

-- ==========================================
-- 4. 创建默认工作流模板
-- ==========================================
-- 删除可能存在的旧模板
DELETE FROM core_workflow_tpls WHERE tp_name = '默认DML工作流';
DELETE FROM core_workflow_tpls WHERE tp_name = '默认DDL工作流';
DELETE FROM core_workflow_tpls WHERE tp_name = '默认查询工作流';

-- 创建DML工作流模板
INSERT INTO core_workflow_tpls (tp_name, steps, type)
VALUES (
    '默认DML工作流',
    '[{"text": "", "auditor": ["admin"], "type": "person"}]',
    0
);

-- 创建DDL工作流模板
INSERT INTO core_workflow_tpls (tp_name, steps, type)
VALUES (
    '默认DDL工作流',
    '[{"text": "", "auditor": ["admin"], "type": "person"}]',
    1
);

-- 创建查询工作流模板
INSERT INTO core_workflow_tpls (tp_name, steps, type)
VALUES (
    '默认查询工作流',
    '[{"text": "", "auditor": ["admin"], "type": "person"}]',
    2
);

-- ==========================================
-- 5. 创建默认审核规则
-- ==========================================
-- 删除可能存在的旧规则
DELETE FROM core_rules WHERE rule_name = '默认审核规则';

-- 创建默认审核规则
INSERT INTO core_rules (rule_name, rule)
VALUES (
    '默认审核规则',
    '{
        "ddl_check_table_comment": true,
        "ddl_check_column_comment": true,
        "ddl_check_column_nullable": true,
        "ddl_check_column_default": true,
        "ddl_enable_drop_table": false,
        "ddl_enable_drop_database": false,
        "ddl_enable_rename": false,
        "dml_max_insert_rows": 1000,
        "dml_max_update_rows": 1000,
        "dml_max_delete_rows": 1000,
        "dml_enable_select_star": false,
        "dml_enable_where_condition": true,
        "query_max_rows": 1000,
        "query_max_execution_time": 60
    }'
);

-- ==========================================
-- 6. 更新全局配置
-- ==========================================
-- 确保存在全局配置记录
INSERT IGNORE INTO core_global_configurations (authorization, other, stmt, audit_role)
VALUES (
    'global',
    '{"idc": ["Local", "Aliyun", "AWS"], "limit": 1000, "query": false, "domain": "", "export": false, "register": false, "ex_query_time": 60}',
    0,
    '{"ddl": "admin", "dml": "admin"}'
);

-- ==========================================
-- 7. 数据源相关函数和过程
-- ==========================================

DELIMITER //

-- 创建数据源的存储过程
CREATE PROCEDURE IF NOT EXISTS CreateDataSource(
    IN p_source_name VARCHAR(50),
    IN p_host VARCHAR(100),
    IN p_port INT,
    IN p_username VARCHAR(50),
    IN p_encrypted_password TEXT,
    IN p_idc VARCHAR(50)
)
BEGIN
    DECLARE v_source_id VARCHAR(100);
    DECLARE v_rule_id INT;
    DECLARE v_flow_dml_id INT;
    DECLARE v_flow_ddl_id INT;
    DECLARE v_flow_query_id INT;

    -- 生成source_id
    SET v_source_id = CONCAT(p_source_name, '-001');

    -- 获取默认规则ID
    SELECT id INTO v_rule_id FROM core_rules WHERE rule_name = '默认审核规则' LIMIT 1;

    -- 获取工作流ID
    SELECT id INTO v_flow_dml_id FROM core_workflow_tpls WHERE tp_name = '默认DML工作流' LIMIT 1;
    SELECT id INTO v_flow_ddl_id FROM core_workflow_tpls WHERE tp_name = '默认DDL工作流' LIMIT 1;
    SELECT id INTO v_flow_query_id FROM core_workflow_tpls WHERE tp_name = '默认查询工作流' LIMIT 1;

    -- 删除可能存在的旧数据源
    DELETE FROM core_data_sources WHERE source = p_source_name;

    -- 创建数据源
    INSERT INTO core_data_sources (
        source, ip, port, username, password, is_query, flow_id, source_id,
        id_c, rule_id, principal, exclude_db_list, insulate_word_list,
        ca_file, cert, key_file, db_type
    ) VALUES (
        p_source_name,
        p_host,
        p_port,
        p_username,
        p_encrypted_password,
        1,  -- 启用查询
        v_flow_query_id,
        v_source_id,
        p_idc,
        v_rule_id,
        '',
        '',
        '',
        '',
        '',
        '',
        0  -- MySQL类型
    );

    -- 更新权限组，添加新的数据源权限
    UPDATE core_role_groups
    SET permissions = JSON_SET(
        permissions,
        '$.ddl_source', JSON_ARRAY_APPEND(JSON_EXTRACT(permissions, '$.ddl_source'), '$', v_source_id),
        '$.dml_source', JSON_ARRAY_APPEND(JSON_EXTRACT(permissions, '$.dml_source'), '$', v_source_id),
        '$.query_source', JSON_ARRAY_APPEND(JSON_EXTRACT(permissions, '$.query_source'), '$', v_source_id)
    )
    WHERE name = 'DBA';

    SELECT CONCAT('数据源 ', p_source_name, ' 创建成功，source_id: ', v_source_id) AS result;
END//

-- 密码加密函数（需要与Go代码中的加密方式一致）
-- 注意：这里使用MySQL的AES加密，实际部署时应使用与Yearning相同的加密方式
CREATE FUNCTION IF NOT EXISTS EncryptPassword(password_text TEXT, secret_key VARCHAR(16))
RETURNS TEXT
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE encrypted_password TEXT;
    -- 使用AES加密（需要确保与Go代码一致）
    SET encrypted_password = TO_BASE64(AES_ENCRYPT(password_text, secret_key));
    RETURN encrypted_password;
END//

DELIMITER ;

-- ==========================================
-- 8. 示例数据源创建
-- ==========================================
-- 注意：以下是示例，实际部署时需要根据具体环境调整

-- 示例：创建本地MySQL数据源
-- CALL CreateDataSource(
--     'local-mysql',           -- 数据源名称
--     '127.0.0.1',            -- 主机
--     3306,                   -- 端口
--     'root',                 -- 用户名
--     'FTFRArh9oSLAR9K+1y6qbQ==',  -- 加密后的密码
--     'local_001'             -- IDC标识
-- );

-- ==========================================
-- 9. 验证初始化结果
-- ==========================================

-- 验证管理员账户
SELECT
    username,
    department,
    real_name,
    email,
    CASE is_recorder
        WHEN 0 THEN '普通用户'
        WHEN 1 THEN '记录员'
        WHEN 2 THEN '管理员'
        ELSE '未知'
    END as user_type
FROM core_accounts
WHERE username = 'admin';

-- 验证权限组
SELECT
    name,
    group_id,
    JSON_PRETTY(permissions) as permissions
FROM core_role_groups
WHERE name = 'DBA';

-- 验证用户权限关联
SELECT
    g.username,
    JSON_PRETTY(g.group) as groups,
    rg.name as group_name
FROM core_graineds g
LEFT JOIN core_role_groups rg ON JSON_CONTAINS(g.group, CONCAT('"', rg.group_id, '"'))
WHERE g.username = 'admin';

-- 验证工作流模板
SELECT
    tp_name,
    CASE type
        WHEN 0 THEN 'DML'
        WHEN 1 THEN 'DDL'
        WHEN 2 THEN 'Query'
        ELSE '未知'
    END as workflow_type,
    steps
FROM core_workflow_tpls
ORDER BY type;

-- 验证审核规则
SELECT
    rule_name,
    JSON_PRETTY(rule) as rule_config
FROM core_rules
WHERE rule_name = '默认审核规则';

-- 验证全局配置
SELECT
    authorization,
    JSON_PRETTY(other) as other_config,
    stmt,
    JSON_PRETTY(audit_role) as audit_roles
FROM core_global_configurations;

-- 验证数据源（如果已创建）
SELECT
    source,
    CONCAT(ip, ':', port) as address,
    username,
    CASE is_query
        WHEN 1 THEN '是'
        ELSE '否'
    END as query_enabled,
    source_id,
    id_c,
    rule_id
FROM core_data_sources;

-- ==========================================
-- 10. 初始化完成提示
-- ==========================================
SELECT
    '数据库初始化完成！' as status,
    '默认管理员: admin' as admin_user,
    '默认密码: Yearning_admin' as admin_password,
    '请访问: http://localhost:8000' as access_url;

-- 显示下一步操作提示
SELECT
    '下一步操作:' as next_steps,
    '1. 修改管理员密码' as step1,
    '2. 创建数据源' as step2,
    '3. 配置用户和权限' as step3,
    '4. 设置审核规则' as step4;
package engine

import (
	"fmt"
	"regexp"
	"strings"
)

// BuiltinSQLChecker 内置SQL检测器
type BuiltinSQLChecker struct{}

// NewBuiltinChecker 创建内置检测器
func NewBuiltinChecker() *BuiltinSQLChecker {
	return &BuiltinSQLChecker{}
}

// Check 执行SQL检测
func (checker *BuiltinSQLChecker) Check(args CheckArgs) []Record {
	var results []Record

	// 分割SQL语句（按分号分割）
	sqlStatements := splitSQL(args.SQL)

	for _, sql := range sqlStatements {
		sql = strings.TrimSpace(sql)
		if sql == "" {
			continue
		}

		record := Record{
			SQL:    sql,
			Schema: args.Schema,
			Status: "通过",
			Level:  0,
		}

		// 执行各种检查
		errors := checker.validateSQL(sql, args.Rule)

		if len(errors) > 0 {
			record.Status = "失败"
			record.Level = 2 // 错误级别
			record.Error = strings.Join(errors, "; ")
		}

		results = append(results, record)
	}

	return results
}

// validateSQL 验证SQL语句
func (checker *BuiltinSQLChecker) validateSQL(sql string, rule AuditRole) []string {
	var errors []string

	// 转换为小写进行检查
	sqlLower := strings.ToLower(strings.TrimSpace(sql))

	// 1. 基础语法检查
	if syntaxErrors := checker.checkBasicSyntax(sqlLower); len(syntaxErrors) > 0 {
		errors = append(errors, syntaxErrors...)
	}

	// 2. DML检查
	if isDML(sqlLower) {
		if dmlErrors := checker.checkDML(sqlLower, rule); len(dmlErrors) > 0 {
			errors = append(errors, dmlErrors...)
		}
	}

	// 3. DDL检查
	if isDDL(sqlLower) {
		if ddlErrors := checker.checkDDL(sqlLower, rule); len(ddlErrors) > 0 {
			errors = append(errors, ddlErrors...)
		}
	}

	// 4. 危险操作检查
	if dangerErrors := checker.checkDangerousOperations(sqlLower, rule); len(dangerErrors) > 0 {
		errors = append(errors, dangerErrors...)
	}

	return errors
}

// checkBasicSyntax 检查基础语法
func (checker *BuiltinSQLChecker) checkBasicSyntax(sql string) []string {
	var errors []string

	// 检查SQL是否为空
	if strings.TrimSpace(sql) == "" {
		errors = append(errors, "SQL语句为空")
		return errors
	}

	// 检查是否以分号结尾（对于单条语句）
	if !strings.HasSuffix(strings.TrimSpace(sql), ";") {
		errors = append(errors, "SQL语句应以分号结尾")
	}

	// 检查基本的括号匹配
	if !isParenthesesBalanced(sql) {
		errors = append(errors, "括号不匹配")
	}

	// 检查基本的引号匹配
	if !isQuotesBalanced(sql) {
		errors = append(errors, "引号不匹配")
	}

	return errors
}

// checkDML 检查DML语句
func (checker *BuiltinSQLChecker) checkDML(sql string, rule AuditRole) []string {
	var errors []string

	// 检查WHERE条件
	if rule.DMLWhere && (strings.Contains(sql, "update ") || strings.Contains(sql, "delete ")) {
		if !strings.Contains(sql, "where ") {
			errors = append(errors, "UPDATE/DELETE语句必须包含WHERE条件")
		}
	}

	// 检查INSERT语句的列名
	if rule.DMLInsertColumns && strings.Contains(sql, "insert ") {
		if !checker.hasInsertColumns(sql) {
			errors = append(errors, "INSERT语句必须显式指定列名")
		}
	}

	// 检查LIMIT使用
	if !rule.DMLAllowLimitSTMT && strings.Contains(sql, "limit ") {
		if strings.Contains(sql, "update ") || strings.Contains(sql, "insert ") {
			errors = append(errors, "UPDATE/INSERT语句不允许使用LIMIT")
		}
	}

	return errors
}

// checkDDL 检查DDL语句
func (checker *BuiltinSQLChecker) checkDDL(sql string, rule AuditRole) []string {
	var errors []string

	// 检查DROP TABLE
	if !rule.DDLEnableDropTable && strings.Contains(sql, "drop table ") {
		errors = append(errors, "不允许执行DROP TABLE操作")
	}

	// 检查DROP DATABASE
	if !rule.DDLEnableDropDatabase && strings.Contains(sql, "drop database ") {
		errors = append(errors, "不允许执行DROP DATABASE操作")
	}

	// 检查CREATE TABLE是否有注释
	if rule.DDLCheckTableComment && strings.Contains(sql, "create table ") {
		if !strings.Contains(sql, "comment ") {
			errors = append(errors, "CREATE TABLE语句必须包含表注释")
		}
	}

	return errors
}

// checkDangerousOperations 检查危险操作
func (checker *BuiltinSQLChecker) checkDangerousOperations(sql string, rule AuditRole) []string {
	var errors []string

	// 检查是否包含危险关键词
	dangerousKeywords := []string{
		"truncate",
		"drop database",
		"drop table",
		"alter table.*drop",
	}

	for _, keyword := range dangerousKeywords {
		if matched, _ := regexp.MatchString(keyword, sql); matched {
			errors = append(errors, fmt.Sprintf("检测到危险操作: %s", keyword))
		}
	}

	// 检查UPDATE/DELETE是否有WHERE条件
	updateRegex := regexp.MustCompile(`update\s+\w+\s+set\s+.*?(?:where|$)`)
	deleteRegex := regexp.MustCompile(`delete\s+from\s+\w+\s*(?:where|$)`)

	if updateRegex.MatchString(sql) && !strings.Contains(sql, "where ") {
		errors = append(errors, "UPDATE语句缺少WHERE条件，可能影响全表数据")
	}

	if deleteRegex.MatchString(sql) && !strings.Contains(sql, "where ") {
		errors = append(errors, "DELETE语句缺少WHERE条件，可能删除全表数据")
	}

	return errors
}

// 辅助函数

// splitSQL 分割SQL语句
func splitSQL(sql string) []string {
	// 简单的按分号分割，实际应该考虑字符串内的分号
	statements := strings.Split(sql, ";")
	var result []string
	for _, stmt := range statements {
		stmt = strings.TrimSpace(stmt)
		if stmt != "" {
			result = append(result, stmt+";")
		}
	}
	return result
}

// isDML 判断是否为DML语句
func isDML(sql string) bool {
	dmlKeywords := []string{"select ", "insert ", "update ", "delete "}
	for _, keyword := range dmlKeywords {
		if strings.HasPrefix(sql, keyword) {
			return true
		}
	}
	return false
}

// isDDL 判断是否为DDL语句
func isDDL(sql string) bool {
	ddlKeywords := []string{"create ", "alter ", "drop ", "truncate "}
	for _, keyword := range ddlKeywords {
		if strings.HasPrefix(sql, keyword) {
			return true
		}
	}
	return false
}

// hasInsertColumns 检查INSERT语句是否有列名
func (checker *BuiltinSQLChecker) hasInsertColumns(sql string) bool {
	// 简单检查：INSERT INTO table (columns) VALUES
	insertRegex := regexp.MustCompile(`insert\s+into\s+\w+\s*\([^)]+\)\s*values`)
	return insertRegex.MatchString(sql)
}

// isParenthesesBalanced 检查括号是否匹配
func isParenthesesBalanced(sql string) bool {
	count := 0
	for _, char := range sql {
		if char == '(' {
			count++
		} else if char == ')' {
			count--
			if count < 0 {
				return false
			}
		}
	}
	return count == 0
}

// isQuotesBalanced 检查引号是否匹配
func isQuotesBalanced(sql string) bool {
	singleQuoteCount := strings.Count(sql, "'") - strings.Count(sql, "\\'")
	doubleQuoteCount := strings.Count(sql, "\"") - strings.Count(sql, "\\\"")
	backtickCount := strings.Count(sql, "`")

	return singleQuoteCount%2 == 0 && doubleQuoteCount%2 == 0 && backtickCount%2 == 0
}
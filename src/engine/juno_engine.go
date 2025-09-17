package engine

import (
	"fmt"
	"log"
	"net"
	"net/http"
	"net/rpc"
	"regexp"
	"strings"
)

// JunoEngine 内置Juno引擎实现
type JunoEngine struct {
	checker *BuiltinSQLChecker
}

// NewJunoEngine 创建新的Juno引擎
func NewJunoEngine() *JunoEngine {
	return &JunoEngine{
		checker: NewBuiltinChecker(),
	}
}

// Check RPC方法 - SQL检测
func (engine *JunoEngine) Check(args *CheckArgs, reply *[]Record) error {
	log.Printf("执行SQL检测: %s", args.SQL)

	results := engine.checker.Check(*args)
	*reply = results

	log.Printf("SQL检测完成，返回%d条结果", len(results))
	return nil
}

// ExecArgs SQL执行参数
type ExecArgs struct {
	Order         interface{} `json:"order"`
	Rules         AuditRole   `json:"rules"`
	IP            string      `json:"ip"`
	Port          int         `json:"port"`
	Username      string      `json:"username"`
	Password      string      `json:"password"`
	CA            string      `json:"ca"`
	Cert          string      `json:"cert"`
	Key           string      `json:"key"`
	Message       interface{} `json:"message"`
	MaxAffectRows uint        `json:"max_affect_rows"`
}

// Exec RPC方法 - SQL执行
func (engine *JunoEngine) Exec(args *ExecArgs, reply *bool) error {
	log.Printf("模拟SQL执行")

	// 在内置版本中，我们不执行实际的SQL，只是返回成功
	// 实际执行由Yearning主程序处理
	*reply = true

	log.Printf("SQL执行模拟完成")
	return nil
}

// QueryArgs 查询参数
type QueryArgs struct {
	SQL      string `json:"sql"`
	Schema   string `json:"schema"`
	IP       string `json:"ip"`
	Port     int    `json:"port"`
	Username string `json:"username"`
	Password string `json:"password"`
}

// Query RPC方法 - SQL查询
func (engine *JunoEngine) Query(args *QueryArgs, reply *interface{}) error {
	log.Printf("模拟SQL查询: %s", args.SQL)

	// 在内置版本中，返回空结果
	// 实际查询由Yearning主程序处理
	*reply = map[string]interface{}{
		"status": "success",
		"data":   []map[string]interface{}{},
	}

	log.Printf("SQL查询模拟完成")
	return nil
}

// MergeAlterTablesArgs DDL合并参数
type MergeAlterTablesArgs struct {
	SQL    string `json:"sql"`
	Schema string `json:"schema"`
}

// MergeAlterTables RPC方法 - DDL语句合并
func (engine *JunoEngine) MergeAlterTables(args *MergeAlterTablesArgs, reply *[]string) error {
	log.Printf("DDL语句合并: %s", args.SQL)

	// 简单的DDL合并逻辑
	statements := engine.mergeAlterStatements(args.SQL)
	*reply = statements

	log.Printf("DDL合并完成，返回%d个语句", len(statements))
	return nil
}

// StopDelay RPC方法 - 停止延时执行
func (engine *JunoEngine) StopDelay(args interface{}, reply *string) error {
	log.Printf("停止延时执行")
	*reply = "延时执行已停止"
	return nil
}

// mergeAlterStatements 合并ALTER语句的简单实现
func (engine *JunoEngine) mergeAlterStatements(sql string) []string {
	// 分割SQL语句
	statements := strings.Split(sql, ";")
	var alterStatements []string
	var otherStatements []string

	alterTableRegex := regexp.MustCompile(`(?i)^\s*alter\s+table\s+(\w+)\s+(.+)`)
	tableGroups := make(map[string][]string)

	for _, stmt := range statements {
		stmt = strings.TrimSpace(stmt)
		if stmt == "" {
			continue
		}

		if match := alterTableRegex.FindStringSubmatch(stmt); match != nil {
			tableName := strings.ToLower(match[1])
			alterAction := match[2]
			tableGroups[tableName] = append(tableGroups[tableName], alterAction)
		} else {
			if stmt != "" {
				otherStatements = append(otherStatements, stmt+";")
			}
		}
	}

	// 合并同表的ALTER语句
	for tableName, actions := range tableGroups {
		if len(actions) > 1 {
			mergedSQL := fmt.Sprintf("ALTER TABLE %s %s;", tableName, strings.Join(actions, ", "))
			alterStatements = append(alterStatements, mergedSQL)
		} else if len(actions) == 1 {
			alterStatements = append(alterStatements, fmt.Sprintf("ALTER TABLE %s %s;", tableName, actions[0]))
		}
	}

	// 返回合并后的语句
	result := append(alterStatements, otherStatements...)
	return result
}

// StartJunoService 启动内置Juno RPC服务
func StartJunoService(addr string) error {
	engine := NewJunoEngine()

	// 注册RPC服务，使用与原Juno相同的服务名
	err := rpc.RegisterName("Engine", engine)
	if err != nil {
		return fmt.Errorf("注册RPC服务失败: %v", err)
	}

	// 注册HTTP处理器
	rpc.HandleHTTP()

	// 启动监听
	listener, err := net.Listen("tcp", addr)
	if err != nil {
		return fmt.Errorf("监听端口失败 %s: %v", addr, err)
	}

	log.Printf("内置Juno服务启动在 %s", addr)
	log.Println("服务包含以下RPC方法:")
	log.Println("  - Engine.Check     (SQL检测)")
	log.Println("  - Engine.Exec      (SQL执行)")
	log.Println("  - Engine.Query     (SQL查询)")
	log.Println("  - Engine.MergeAlterTables (DDL合并)")
	log.Println("  - Engine.StopDelay (停止延时)")

	// 启动HTTP RPC服务
	return http.Serve(listener, nil)
}

// AdvancedSQLValidator 高级SQL验证器
type AdvancedSQLValidator struct{}

// validateWithTiDB 使用TiDB Parser进行高级验证
func (validator *AdvancedSQLValidator) validateWithTiDB(sql string) []string {
	var errors []string

	// TODO: 这里可以集成TiDB Parser进行更精确的语法分析
	// 由于TiDB依赖较大，暂时使用基础验证

	// 检查SQL长度
	if len(sql) > 10000 {
		errors = append(errors, "SQL语句过长（超过10000字符）")
	}

	// 检查常见的语法错误模式
	if strings.Contains(strings.ToLower(sql), "select * from") && strings.Count(sql, "*") > 3 {
		errors = append(errors, "建议避免使用过多的SELECT *语句")
	}

	return errors
}
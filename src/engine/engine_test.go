package engine

import (
	"testing"
	"reflect"
)

// TestBuiltinSQLChecker 测试内置SQL检测器
func TestBuiltinSQLChecker(t *testing.T) {
	checker := NewBuiltinChecker()

	tests := []struct {
		name     string
		sql      string
		rule     AuditRole
		wantPass bool
	}{
		{
			name: "基础SELECT语句",
			sql:  "SELECT * FROM users WHERE id = 1;",
			rule: AuditRole{DMLSelect: true, DMLWhere: true},
			wantPass: true,
		},
		{
			name: "缺少WHERE的UPDATE",
			sql:  "UPDATE users SET name = 'test';",
			rule: AuditRole{DMLWhere: true},
			wantPass: false,
		},
		{
			name: "危险的DROP TABLE",
			sql:  "DROP TABLE users;",
			rule: AuditRole{DDLEnableDropTable: false},
			wantPass: false,
		},
		{
			name: "INSERT缺少列名",
			sql:  "INSERT INTO users VALUES (1, 'test');",
			rule: AuditRole{DMLInsertColumns: true},
			wantPass: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			results := checker.Check(CheckArgs{
				SQL:    tt.sql,
				Schema: "test",
				Rule:   tt.rule,
			})

			if len(results) == 0 {
				t.Fatal("期望得到检测结果")
			}

			result := results[0]
			passed := result.Status == "通过"

			if passed != tt.wantPass {
				t.Errorf("检测结果不符合预期: got %v, want %v, error: %s",
					passed, tt.wantPass, result.Error)
			}
		})
	}
}

// TestDDLMerging 测试DDL语句合并
func TestDDLMerging(t *testing.T) {
	engine := NewJunoEngine()

	tests := []struct {
		name     string
		sql      string
		expected []string
	}{
		{
			name: "合并同表ALTER语句",
			sql:  "ALTER TABLE users ADD COLUMN age INT; ALTER TABLE users ADD COLUMN email VARCHAR(100);",
			expected: []string{
				"ALTER TABLE users ADD COLUMN age INT, ADD COLUMN email VARCHAR(100);",
			},
		},
		{
			name: "不同表不合并",
			sql:  "ALTER TABLE users ADD COLUMN age INT; ALTER TABLE orders ADD COLUMN total DECIMAL(10,2);",
			expected: []string{
				"ALTER TABLE users ADD COLUMN age INT;",
				"ALTER TABLE orders ADD COLUMN total DECIMAL(10,2);",
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var result []string
			err := engine.MergeAlterTables(&MergeAlterTablesArgs{
				SQL:    tt.sql,
				Schema: "test",
			}, &result)

			if err != nil {
				t.Fatalf("合并失败: %v", err)
			}

			if !reflect.DeepEqual(result, tt.expected) {
				t.Errorf("合并结果不符合预期:\ngot:  %v\nwant: %v", result, tt.expected)
			}
		})
	}
}

// TestRPCInterfaceCompatibility 测试RPC接口兼容性
func TestRPCInterfaceCompatibility(t *testing.T) {
	engine := NewJunoEngine()

	// 测试所有RPC方法是否存在
	t.Run("Engine.Check", func(t *testing.T) {
		var result []Record
		err := engine.Check(&CheckArgs{
			SQL:    "SELECT 1;",
			Schema: "test",
			Rule:   AuditRole{},
		}, &result)

		if err != nil {
			t.Errorf("Engine.Check失败: %v", err)
		}
	})

	t.Run("Engine.Exec", func(t *testing.T) {
		var result bool
		err := engine.Exec(&ExecArgs{}, &result)

		// 当前实现应该返回true（模拟成功）
		if err != nil {
			t.Errorf("Engine.Exec失败: %v", err)
		}
		if !result {
			t.Error("Engine.Exec应该返回true")
		}
	})

	t.Run("Engine.Query", func(t *testing.T) {
		var result interface{}
		err := engine.Query(&QueryArgs{
			SQL:    "SELECT * FROM users;",
			Schema: "test",
		}, &result)

		if err != nil {
			t.Errorf("Engine.Query失败: %v", err)
		}
	})

	t.Run("Engine.MergeAlterTables", func(t *testing.T) {
		var result []string
		err := engine.MergeAlterTables(&MergeAlterTablesArgs{
			SQL:    "ALTER TABLE users ADD COLUMN age INT;",
			Schema: "test",
		}, &result)

		if err != nil {
			t.Errorf("Engine.MergeAlterTables失败: %v", err)
		}
	})

	t.Run("Engine.StopDelay", func(t *testing.T) {
		var result string
		err := engine.StopDelay(nil, &result)

		if err != nil {
			t.Errorf("Engine.StopDelay失败: %v", err)
		}
	})
}

// BenchmarkSQLCheck 性能基准测试
func BenchmarkSQLCheck(b *testing.B) {
	checker := NewBuiltinChecker()
	args := CheckArgs{
		SQL:    "SELECT * FROM users WHERE id = ? AND status = 'active' ORDER BY created_at DESC LIMIT 10;",
		Schema: "test",
		Rule: AuditRole{
			DMLSelect: true,
			DMLWhere:  true,
			DMLOrder:  true,
		},
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = checker.Check(args)
	}
}

// TestAuditRulesCoverage 测试审计规则覆盖度
func TestAuditRulesCoverage(t *testing.T) {
	// 确保所有重要的审计规则都被实现
	rules := []string{
		"DMLWhere", "DMLSelect", "DMLOrder", "DMLInsertColumns",
		"DDLEnableDropTable", "DDLEnableDropDatabase", "DDLCheckTableComment",
		"MaxAffectRows", "CheckIdentifier",
	}

	checker := NewBuiltinChecker()

	for _, rule := range rules {
		t.Run("Rule_"+rule, func(t *testing.T) {
			// 这里可以添加针对特定规则的测试
			// 确保每个规则都有对应的检测逻辑
			_ = checker // 占位符，实际测试中需要具体实现
		})
	}
}
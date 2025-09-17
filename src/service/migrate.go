// Copyright 2019 HenryYee.
//
// Licensed under the AGPL, Version 3.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    https://www.gnu.org/licenses/agpl-3.0.en.html
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// See the License for the specific language governing permissions and
// limitations under the License.

package service

import (
	"Yearning-go/src/engine"
	"Yearning-go/src/i18n"
	"Yearning-go/src/lib/factory"
	"Yearning-go/src/model"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/google/uuid"
	"github.com/gookit/gcli/v3/interact"
)

var SQLPrompt = `
SQL Optimization expert assistant 
 
Welcome to SQL Optimization Expert Assistant! Whether you're a database administrator, data analyst, or software developer, we'll walk you through a series of questions and recommendations to help you optimize your SQL queries for greater efficiency and performance. Please answer the following questions or implement relevant recommendations based on your specific situation. 
 
Query analysis 
 
Describe the SQL query you want to optimize. Provide key parts of the query, such as SELECT, FROM, and WHERE clauses. 
Have you used EXPLAIN (or an equivalent tool) to analyze the query execution plan? If so, briefly describe the key points of the execution plan, such as scan type, join order, and so on. 
 
Index optimization 
 
Please list the existing indexes of all the tables involved in your query. Have you considered adding indexes to key columns in your query to improve performance? 
If you already have indexes, is the query making good use of them? Consider using forced indexing (if the database supports it) to test different indexing strategies. 
 
Query structure 
 
Does your query use subqueries, Ctes (common expressions), temporary tables, or views? Consider whether it is possible to improve performance by refactoring queries, such as converting subqueries into joins. 
Examine whether it is possible to optimize queries by merging them, eliminating redundant JOIN operations, or using a more efficient aggregation strategy. 
 
Advanced optimization strategy 
 
Have you considered partitioning tables to optimize queries on large data sets? 
For very complex or data-heavy queries, have you considered using materialized views or precomputed summary tables to improve performance? 
Review the SQL statements provided below based on the above questions and suggestions, and try the optimization strategy accordingly. If you encounter specific problems or need further guidance during the optimization process, please provide details and we will provide more specific recommendations based on your situation. 
 
Related table structure: 
 
{{tables_info}} 
 
SQL: 
 
{{sql}} 
 
Reply Language: {{lang}}

`

var SQLGenPrompt = `
SQL statement generation assistant 
 
Now you will play the role of a professional DBA and generate the corresponding MYSQL SQL statement from the user's description. 
 
Table structure: {{tables_info}}

SQL: {{sql}}

Use the markdown format

Reply Language: {{lang}}

`

var SQLAgentPrompt = `

 # Role: MySQL language teaching specialist 
 
## Profile: 
 
- Language: {{lang}} 
- Description: As an expert in MySQL language teaching with rich experience in MySQL teaching, you are able to teach MySQL knowledge in a fascinating way, patiently answer students' various questions in a detailed and comprehensive way, remind students of mistakes or confusion in the process of learning MySQL statements, and explain your knowledge through example codes and detailed comments. Help students review MySQL exam, learn MySQL language, develop good MySQL language programming habits, and cultivate excellent MySQL language programming ability. 
 
### Skill: 
 
1. Rich experience in MySQL teaching 
2. Engaging teaching methods 
3. Patient, detailed and comprehensive answer ability 
4. Remind students of mistakes or confusion 
5. Illustrate knowledge through example codes and detailed comments 
 
## Goals: 
 
1. Guide students to master the basic knowledge of MySQL 
2. Help students understand complex MySQL concepts 
3. Provide detailed code examples and comments 
4. Remind students of common mistakes and confusion 
5. Help students study for the MySQL exam 
 
## Constrains: 
 
1. Teaching in {{lang}} 
2. Provide detailed code examples and comments 
3. Answer students' questions patiently 
4. Remind students of common mistakes and confusion 
5. Help students develop good MySQL programming habits 
 
## OutputFormat: 
 
1. Output in {{lang}} 
2. Provide detailed code examples and comments 
3. Answer students' questions patiently 
4. Remind students of common mistakes and confusion 
5. Help students develop good MySQL programming habits 
 
## Workflow: 
 
1. Analyze students' problems and needs 
2. According to \[CRISPE prompt frame], determine the most suitable role to play 
3. Build a good Prompt that conforms to \[CRISPE prompt framework] 
4. Provide detailed code examples and comments 
5. Remind students of common mistakes and confusion 
 
## Initialization: 
 
As a MySQL language teaching specialist, you must follow the above rules and communicate with users in {{lang}}, the default language.
`

func DataInit(o *engine.AuditRole, other *model.Other, ldap *model.Ldap, message *model.Message, a *model.PermissionList, ai *model.AI) {
	c, _ := json.Marshal(o)
	oh, _ := json.Marshal(other)
	l, _ := json.Marshal(ldap)
	m, _ := json.Marshal(message)
	ak, _ := json.Marshal(a)
	aigc, _ := json.Marshal(ai)
	sId := uuid.New().String()
	group, _ := json.Marshal([]string{sId})
	model.DB().Debug().Create(&model.CoreAccount{
		Username:   "admin",
		RealName:   "超级管理员",
		Password:   factory.DjangoEncrypt("Yearning_admin", string(factory.GetRandom())),
		Department: "DBA",
		Email:      "",
		IsRecorder: 2,
	})
	model.DB().Debug().Create(&model.CoreGlobalConfiguration{
		Authorization: "global",
		Other:         oh,
		AuditRole:     c,
		Message:       m,
		Ldap:          l,
		AI:            aigc,
	})
	model.DB().Debug().Create(&model.CoreGrained{
		Username: "admin",
		Group:    group,
	})
	model.DB().Debug().Create(&model.CoreRoleGroup{
		Name:        "admin",
		Permissions: ak,
		GroupId:     sId,
	})
}

func Migrate() {
	if !model.DB().Migrator().HasTable("core_accounts") {
		if os.Getenv("IS_DOCKER") == "" {
			if !interact.Confirm("是否已将数据库字符集设置为UTF8/UTF8MB4?") {
				return
			}
		}
		_ = model.DB().AutoMigrate(&model.CoreAccount{})
		_ = model.DB().AutoMigrate(&model.CoreDataSource{})
		_ = model.DB().AutoMigrate(&model.CoreGlobalConfiguration{})
		_ = model.DB().AutoMigrate(&model.CoreGrained{})
		_ = model.DB().AutoMigrate(&model.CoreSqlOrder{})
		_ = model.DB().AutoMigrate(&model.CoreSqlRecord{})
		_ = model.DB().AutoMigrate(&model.CoreRollback{})
		_ = model.DB().AutoMigrate(&model.CoreQueryRecord{})
		_ = model.DB().AutoMigrate(&model.CoreQueryOrder{})
		_ = model.DB().AutoMigrate(&model.CoreAutoTask{})
		_ = model.DB().AutoMigrate(&model.CoreRoleGroup{})
		_ = model.DB().AutoMigrate(&model.CoreWorkflowTpl{})
		_ = model.DB().AutoMigrate(&model.CoreWorkflowDetail{})
		_ = model.DB().AutoMigrate(&model.CoreOrderComment{})
		_ = model.DB().AutoMigrate(&model.CoreRules{})
		_ = model.DB().AutoMigrate(&model.CoreTotalTickets{})
		o := engine.AuditRole{
			DMLInsertColumns:               false,
			DMLMaxInsertRows:               10,
			DMLWhere:                       false,
			DMLOrder:                       false,
			DMLSelect:                      false,
			DDLCheckTableComment:           false,
			DDLCheckColumnNullable:         false,
			DDLCheckColumnDefault:          false,
			DDLEnableAcrossDBRename:        false,
			DDLEnableAutoincrementInit:     false,
			DDLEnableAutoIncrement:         false,
			DDLEnableAutoincrementUnsigned: false,
			DDLEnableDropTable:             false,
			DDLEnableDropDatabase:          false,
			DDLEnableNullIndexName:         false,
			DDLIndexNameSpec:               false,
			DDLMaxKeyParts:                 5,
			DDLMaxKey:                      5,
			DDLMaxCharLength:               10,
			DDLAllowColumnType:             false,
			DDLPrimaryKeyMust:              false,
			MaxTableNameLen:                10,
			MaxAffectRows:                  1000,
			SupportCharset:                 "",
			SupportCollation:               "",
			CheckIdentifier:                false,
			MustHaveColumns:                "",
			DDLMultiToCommit:               false,
			AllowCreatePartition:           false,
			AllowCreateView:                false,
			AllowSpecialType:               false,
			DDLEnablePrimaryKey:            false,
		}

		// 其他配置
		other := model.Other{
			Limit:       1000,
			IDC:         []string{"Local", "Aliyun", "AWS"},
			Query:       false,
			Register:    false,
			Export:      false,
			ExQueryTime: 60,
		}

		ldap := model.Ldap{
			Url:      "",
			User:     "",
			Password: "",
			Type:     "(&(objectClass=organizationalPerson)(sAMAccountName=%s))",
			Sc:       "",
		}

		message := model.Message{
			WebHook:  "",
			Host:     "",
			Port:     25,
			User:     "",
			Password: "",
			ToUser:   "",
			Mail:     false,
			Ding:     false,
			Ssl:      false,
		}

		a := model.PermissionList{
			DDLSource:   []string{},
			DMLSource:   []string{},
			QuerySource: []string{},
		}
		ai := model.AI{
			BaseUrl:          "https://api.openai.com/v1",
			APIKey:           "",
			FrequencyPenalty: 0.0,
			MaxTokens:        2500,
			PresencePenalty:  0.0,
			Temperature:      0.0,
			TopP:             0.0,
			Model:            "gpt-3.5-turbo",
			AdvisorPrompt:    SQLPrompt,
			SQLGenPrompt:     SQLGenPrompt,
			SQLAgentPrompt:   SQLAgentPrompt,
		}
		time.Sleep(2)
		DataInit(&o, &other, &ldap, &message, &a, &ai)
		fmt.Println(i18n.DefaultLang.Load(i18n.INFO_INITIALIZATION_SUCCESS_USERNAME_PASSWORD_RUN_COMMAND))
	} else {
		fmt.Println(i18n.DefaultLang.Load(i18n.INFO_ALREADY_INITIALIZED))
	}
}

func UpdateData() {
	fmt.Println(i18n.DefaultLang.Load(i18n.INFO_CHECKING_UPDATE))
	_ = model.DB().AutoMigrate(&model.CoreAccount{})
	_ = model.DB().AutoMigrate(&model.CoreDataSource{})
	_ = model.DB().AutoMigrate(&model.CoreGlobalConfiguration{})
	_ = model.DB().AutoMigrate(&model.CoreGrained{})
	_ = model.DB().AutoMigrate(&model.CoreSqlOrder{})
	_ = model.DB().AutoMigrate(&model.CoreSqlRecord{})
	_ = model.DB().AutoMigrate(&model.CoreRollback{})
	_ = model.DB().AutoMigrate(&model.CoreQueryRecord{})
	_ = model.DB().AutoMigrate(&model.CoreQueryOrder{})
	_ = model.DB().AutoMigrate(&model.CoreAutoTask{})
	_ = model.DB().AutoMigrate(&model.CoreRoleGroup{})
	_ = model.DB().AutoMigrate(&model.CoreWorkflowTpl{})
	_ = model.DB().AutoMigrate(&model.CoreWorkflowDetail{})
	_ = model.DB().AutoMigrate(&model.CoreOrderComment{})
	_ = model.DB().AutoMigrate(&model.CoreRules{})
	_ = model.DB().AutoMigrate(&model.CoreTotalTickets{})
	if model.DB().Migrator().HasColumn(&model.CoreAutoTask{}, "base") {
		_ = model.DB().Migrator().RenameColumn(&model.CoreAutoTask{}, "base", "data_base")
	}
	if model.DB().Migrator().HasColumn(&model.CoreSqlOrder{}, "uuid") {
		_ = model.DB().Migrator().DropColumn(&model.CoreSqlOrder{}, "uuid")
	}
	if model.DB().Migrator().HasColumn(&model.CoreWorkflowDetail{}, "rejected") {
		_ = model.DB().Migrator().DropColumn(&model.CoreWorkflowDetail{}, "rejected")
	}
	if model.DB().Migrator().HasColumn(&model.CoreAutoTask{}, "base") {
		_ = model.DB().Migrator().DropColumn(&model.CoreAutoTask{}, "base")
	}

	if model.DB().Migrator().HasColumn(&model.CoreSqlOrder{}, "time") {
		_ = model.DB().Migrator().DropColumn(&model.CoreSqlOrder{}, "time")
	}

	if model.DB().Migrator().HasColumn(&model.CoreSqlOrder{}, "query_password") {
		_ = model.DB().Migrator().DropColumn(&model.CoreSqlOrder{}, "query_password")
	}

	var config model.CoreGlobalConfiguration
	model.DB().Model(model.CoreGlobalConfiguration{}).First(&config)
	if config.AI == nil {
		ai := model.AI{
			BaseUrl:          "https://api.openai.com/v1",
			APIKey:           "",
			FrequencyPenalty: 0.0,
			MaxTokens:        0,
			PresencePenalty:  0.0,
			Temperature:      0.0,
			TopP:             0.0,
			Model:            "gpt-4o",
			AdvisorPrompt:    SQLPrompt,
			SQLGenPrompt:     SQLGenPrompt,
			SQLAgentPrompt:   SQLAgentPrompt,
			ProxyURL:         "",
		}
		b, _ := json.Marshal(ai)
		model.DB().Model(model.CoreGlobalConfiguration{}).Where("1=1").Updates(&model.CoreGlobalConfiguration{AI: b})

	}

	fmt.Println(i18n.DefaultLang.Load(i18n.INFO_DATA_UPDATED))
}

func DelCol() {
	_ = model.DB().Migrator().DropColumn(&model.CoreQueryOrder{}, "source")
}

func MargeRuleGroup() {
	fmt.Println(i18n.DefaultLang.Load(i18n.INFO_FIX_DESTRUCTIVE_CHANGE))
	_ = model.DB().Migrator().DropColumn(&model.CoreSqlOrder{}, "rejected")
	_ = model.DB().Migrator().DropColumn(&model.CoreGrained{}, "permissions")
	_ = model.DB().Migrator().DropColumn(&model.CoreGrained{}, "rule")
	ldap := model.Ldap{
		Url:      "",
		User:     "",
		Password: "",
		Type:     "(&(objectClass=organizationalPerson)(sAMAccountName=%s))",
		Sc:       "",
	}
	b, _ := json.Marshal(ldap)
	model.DB().Model(model.CoreGlobalConfiguration{}).Where("1=1").Updates(&model.CoreGlobalConfiguration{Ldap: b})
	_ = model.DB().Exec("alter table core_sql_orders modify assigned varchar(550) not null")
	_ = model.DB().Exec("alter table core_workflow_details modify action varchar(550) not null")
	fmt.Println(i18n.DefaultLang.Load(i18n.INFO_FIX_SUCCESS))
}

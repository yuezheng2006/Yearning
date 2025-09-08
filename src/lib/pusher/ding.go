package pusher

import (
	"Yearning-go/src/i18n"
	"Yearning-go/src/model"
	"crypto/hmac"
	"crypto/sha256"
	"crypto/tls"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strings"
	"time"
)

type imCryGeneric struct {
	Assigned string
	WorkId   string
	Source   string
	Username string
	Text     string
}

// 钉钉消息模板
var DingTemplate = `
{
        "msgtype": "markdown",
        "markdown": {
                "title": "Yearning",
                "text": "## Yearning工单通知 \n\n **工单编号:** $WORKID\n\n **数据源:** $SOURCE\n\n **工单说明:** $TEXT\n\n **提交人员:** <font color = \"#78beea\">$USER</font> \n \n **下一步操作人:** <font color=\"#fe8696\">$AUDITOR</font> \n \n **平台地址:** [$HOST]($HOST) \n \n  **状态:** <font color=\"#1abefa\">$STATE</font> \n \n"
        }
}
`

// 飞书消息模板 - 带可点击按钮
var FeishuTemplate = `
{
    "msg_type": "interactive",
    "card": {
        "header": {
            "title": {
                "content": "📋 Yearning工单通知",
                "tag": "plain_text"
            }
        },
        "elements": [
            {
                "tag": "div",
                "text": {
                    "content": "**$AUDITOR** 您有新的工单待审批",
                    "tag": "lark_md"
                }
            },
            {
                "tag": "hr"
            },
            {
                "tag": "div",
                "fields": [
                    {
                        "is_short": true,
                        "text": {
                            "content": "**工单编号:** $WORKID",
                            "tag": "lark_md"
                        }
                    },
                    {
                        "is_short": true,
                        "text": {
                            "content": "**状态:** $STATE",
                            "tag": "lark_md"
                        }
                    }
                ]
            },
            {
                "tag": "div",
                "fields": [
                    {
                        "is_short": true,
                        "text": {
                            "content": "**数据源:** $SOURCE",
                            "tag": "lark_md"
                        }
                    },
                    {
                        "is_short": true,
                        "text": {
                            "content": "**提交人员:** $USER",
                            "tag": "lark_md"
                        }
                    }
                ]
            },
            {
                "tag": "div",
                "text": {
                    "content": "**工单说明:** $TEXT",
                    "tag": "lark_md"
                }
            },
            {
                "tag": "hr"
            },
            {
                "tag": "action",
                "actions": [
                    {
                        "tag": "button",
                        "text": {
                            "content": "🔍 查看工单",
                            "tag": "plain_text"
                        },
                        "type": "primary",
                        "url": "$HOST/#/server/order/audit/list"
                    },
                    {
                        "tag": "button",
                        "text": {
                            "content": "📋 立即审核",
                            "tag": "plain_text"
                        },
                        "type": "default",
                        "url": "$HOST/#/server/order/audit/list"
                    }
                ]
            },
            {
                "tag": "div",
                "text": {
                    "content": "📍 点击按钮直接跳转到审核页面",
                    "tag": "lark_md"
                }
            },
            {
                "tag": "note",
                "elements": [
                    {
                        "tag": "plain_text",
                        "content": "请及时处理工单"
                    }
                ]
            }
        ]
    }
}
`

// 保持向后兼容
var Commontext = DingTemplate

// 检测webhook类型
func detectWebhookType(webhookURL string) string {
	if strings.Contains(webhookURL, "open.feishu.cn") || strings.Contains(webhookURL, "open.larksuite.com") {
		return "feishu"
	}
	// 默认为钉钉类型
	return "ding"
}

// 将钉钉格式消息转换为飞书格式
func convertToFeishuFormat(dingMessage string) string {
	// 从钉钉JSON中提取关键信息
	var dingData map[string]interface{}
	if err := json.Unmarshal([]byte(dingMessage), &dingData); err != nil {
		// 如果解析失败，返回简单的飞书消息
		return `{"msg_type": "text", "content": {"text": "Yearning工单通知"}}`
	}
	
	// 提取markdown内容
	var text string
	if markdown, ok := dingData["markdown"].(map[string]interface{}); ok {
		if content, ok := markdown["text"].(string); ok {
			text = content
		}
	}
	
	// 解析钉钉markdown内容，提取关键字段
	workId := extractField(text, "工单编号")
	source := extractField(text, "数据源")
	description := extractField(text, "工单说明")
	user := extractField(text, "提交人员")
	auditor := extractField(text, "下一步操作人")
	state := extractField(text, "状态")
	host := extractField(text, "平台地址")
	
	// 构建飞书Interactive Card
	feishuCard := map[string]interface{}{
		"msg_type": "interactive",
		"card": map[string]interface{}{
			"header": map[string]interface{}{
				"title": map[string]interface{}{
					"content": "📋 Yearning工单通知",
					"tag":     "plain_text",
				},
			},
			"elements": []interface{}{
				map[string]interface{}{
					"tag": "div",
					"text": map[string]interface{}{
						"content": "**" + auditor + "** 您有新的工单待审批",
						"tag":     "lark_md",
					},
				},
				map[string]interface{}{"tag": "hr"},
				map[string]interface{}{
					"tag": "div",
					"fields": []interface{}{
						map[string]interface{}{
							"is_short": true,
							"text": map[string]interface{}{
								"content": "**工单编号:** " + workId,
								"tag":     "lark_md",
							},
						},
						map[string]interface{}{
							"is_short": true,
							"text": map[string]interface{}{
								"content": "**状态:** " + state,
								"tag":     "lark_md",
							},
						},
					},
				},
				map[string]interface{}{
					"tag": "div",
					"fields": []interface{}{
						map[string]interface{}{
							"is_short": true,
							"text": map[string]interface{}{
								"content": "**数据源:** " + source,
								"tag":     "lark_md",
							},
						},
						map[string]interface{}{
							"is_short": true,
							"text": map[string]interface{}{
								"content": "**提交人员:** " + user,
								"tag":     "lark_md",
							},
						},
					},
				},
				map[string]interface{}{
					"tag": "div",
					"text": map[string]interface{}{
						"content": "**工单说明:** " + description,
						"tag":     "lark_md",
					},
				},
				map[string]interface{}{"tag": "hr"},
				map[string]interface{}{
					"tag": "action",
					"actions": []interface{}{
						map[string]interface{}{
							"tag": "button",
							"text": map[string]interface{}{
								"content": "🔍 查看工单",
								"tag":     "plain_text",
							},
							"type": "primary",
							"url":  host + "/#/server/order/audit/list",
						},
						map[string]interface{}{
							"tag": "button",
							"text": map[string]interface{}{
								"content": "📋 立即审核",
								"tag":     "plain_text",
							},
							"type": "default",
							"url":  host + "/#/server/order/audit/list",
						},
					},
				},
				map[string]interface{}{
					"tag": "div",
					"text": map[string]interface{}{
						"content": "📍 点击按钮直接跳转到审核页面",
						"tag":     "lark_md",
					},
				},
				map[string]interface{}{
					"tag": "note",
					"elements": []interface{}{
						map[string]interface{}{
							"tag":     "plain_text",
							"content": "请及时处理工单",
						},
					},
				},
			},
		},
	}
	
	// 转换为JSON字符串
	result, _ := json.Marshal(feishuCard)
	return string(result)
}

// 从markdown文本中提取字段值
func extractField(text, fieldName string) string {
	// 使用正则表达式提取字段值
	pattern := `\*\*` + fieldName + `:\*\*\s*([^\\n]*)`
	re := regexp.MustCompile(pattern)
	matches := re.FindStringSubmatch(text)
	if len(matches) > 1 {
		return strings.TrimSpace(matches[1])
	}
	return ""
}

func PusherMessages(msg model.Message, sv string) {
	// 向后兼容：如果使用旧配置，智能检测webhook类型
	if msg.WebHook != "" {
		webhookType := detectWebhookType(msg.WebHook)
		message := sv
		
		// 如果是飞书webhook，需要转换消息格式
		if webhookType == "feishu" {
			message = convertToFeishuFormat(sv)
		}
		
		sendToWebHook(msg.WebHook, msg.Key, message, webhookType)
		return
	}

	// 新逻辑：支持多webhook
	for _, webhook := range msg.WebHooks {
		if !webhook.Enabled {
			continue
		}

		// 根据类型选择模板
		message := formatMessage(webhook, sv)
		sendToWebHook(webhook.URL, webhook.Secret, message, webhook.Type)
	}
}

// 通用webhook发送函数
func sendToWebHook(hookURL, secret, message, webhookType string) {
	hook := hookURL

	// 根据类型处理签名
	if secret != "" {
		switch webhookType {
		case "feishu":
			hook = signFeishu(secret, hookURL)
		default: // ding 或其他
			hook = Sign(secret, hookURL)
		}
	}

	model.DefaultLogger.Debugf("hook:%v", hook)
	model.DefaultLogger.Debugf("message:%v", message)

	req, err := http.NewRequest("POST", hook, strings.NewReader(message))
	if err != nil {
		model.DefaultLogger.Errorf("request:", err)
		return
	}

	tr := &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
	}

	client := &http.Client{Transport: tr}
	req.Header.Set("Content-Type", "application/json; charset=utf-8")

	resp, err := client.Do(req)
	if err != nil {
		model.DefaultLogger.Errorf("resp:", err)
		return
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	model.DefaultLogger.Debugf("resp:%v", string(body))
}

// 通用消息格式化
func formatMessage(webhook model.WebHookConfig, data string) string {
	// 对于自定义模板，使用用户配置的模板
	if webhook.Type == "custom" && webhook.Template != "" {
		// 自定义模板需要进行变量替换
		return replaceMessageVariables(webhook.Template, data)
	}

	// 对于飞书类型，使用飞书模板
	if webhook.Type == "feishu" {
		template := FeishuTemplate
		if webhook.Template != "" {
			template = webhook.Template
		}
		return replaceMessageVariables(template, data)
	}

	// 默认钉钉格式，直接返回
	return data
}

// 变量替换辅助函数 - 从已格式化的钉钉消息中提取变量并应用到新模板
func replaceMessageVariables(template, dingData string) string {
	// 从钉钉格式的JSON中提取变量值
	var dingObj map[string]interface{}
	if err := json.Unmarshal([]byte(dingData), &dingObj); err != nil {
		model.DefaultLogger.Errorf("解析钉钉消息失败: %v", err)
		return template
	}
	
	// 提取markdown内容
	var markdownText string
	if markdown, ok := dingObj["markdown"].(map[string]interface{}); ok {
		if text, ok := markdown["text"].(string); ok {
			markdownText = text
		}
	}
	
	if markdownText == "" {
		return template
	}
	
	// 提取各个变量值
	workId := extractField(markdownText, "工单编号")
	source := extractField(markdownText, "数据源")
	text := extractField(markdownText, "工单说明")
	user := extractField(markdownText, "提交人员")
	auditor := extractField(markdownText, "下一步操作人")
	state := extractField(markdownText, "状态")
	host := model.GloOther.Domain
	
	// 执行变量替换
	result := template
	result = strings.Replace(result, "$WORKID", workId, -1)
	result = strings.Replace(result, "$SOURCE", source, -1)
	result = strings.Replace(result, "$TEXT", text, -1)
	result = strings.Replace(result, "$USER", user, -1)
	result = strings.Replace(result, "$AUDITOR", auditor, -1)
	result = strings.Replace(result, "$STATE", state, -1)
	result = strings.Replace(result, "$HOST", host, -1)
	
	return result
}

// 飞书签名验证（简化版，实际可能需要根据飞书文档调整）
func signFeishu(secret, hook string) string {
	timestamp := time.Now().Unix()
	stringToSign := fmt.Sprintf("%d\n%s", timestamp, secret)
	sign := hmacSha256(stringToSign, secret)
	return fmt.Sprintf("%s&timestamp=%d&sign=%s", hook, timestamp, sign)
}

func Sign(secret, hook string) string {
	timestamp := time.Now().UnixNano() / 1e6
	stringToSign := fmt.Sprintf("%d\n%s", timestamp, secret)
	sign := hmacSha256(stringToSign, secret)
	url := fmt.Sprintf("%s&timestamp=%d&sign=%s", hook, timestamp, sign)
	return url
}

func dingMsgTplHandler(state string, generic interface{}) string {
	return msgTplHandler(state, generic, DingTemplate)
}

// 通用消息模板处理函数
func msgTplHandler(state string, generic interface{}, template string) string {
	var order imCryGeneric
	switch v := generic.(type) {
	case model.CoreSqlOrder:
		order = imCryGeneric{
			Assigned: v.Assigned,
			WorkId:   v.WorkId,
			Source:   v.Source,
			Username: v.Username,
			Text:     v.Text,
		}
	case model.CoreQueryOrder:
		order = imCryGeneric{
			Assigned: v.Assigned,
			WorkId:   v.WorkId + i18n.DefaultLang.Load(i18n.INFO_QUERY),
			Source:   i18n.DefaultLang.Load(i18n.ER_QUERY_NO_DATA_SOURCE),
			Username: v.Username,
			Text:     v.Text,
		}
	}
	
	text := template
	if !stateHandler(state) {
		order.Assigned = "无"
	}
	
	// 通用变量替换
	text = strings.Replace(text, "$STATE", state, -1)
	text = strings.Replace(text, "$WORKID", order.WorkId, -1)
	text = strings.Replace(text, "$SOURCE", order.Source, -1)
	text = strings.Replace(text, "$HOST", model.GloOther.Domain, -1)
	text = strings.Replace(text, "$USER", order.Username, -1)
	text = strings.Replace(text, "$AUDITOR", order.Assigned, -1)
	text = strings.Replace(text, "$TEXT", order.Text, -1)
	
	model.DefaultLogger.Debugf("format:%v", text)
	return text
}

// 飞书消息处理函数
func feishuMsgTplHandler(state string, generic interface{}) string {
	return msgTplHandler(state, generic, FeishuTemplate)
}

func stateHandler(state string) bool {
	switch state {
	case i18n.DefaultLang.Load(i18n.INFO_TRANSFERRED_TO_NEXT_AGENT), i18n.DefaultLang.Load(i18n.INFO_SUBMITTED):
		return true
	}
	return false
}

func hmacSha256(stringToSign string, secret string) string {
	h := hmac.New(sha256.New, []byte(secret))
	h.Write([]byte(stringToSign))
	return base64.StdEncoding.EncodeToString(h.Sum(nil))
}

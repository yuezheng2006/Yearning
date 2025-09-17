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

var Commontext = `
{
        "msgtype": "markdown",
        "markdown": {
                "title": "Yearning",
                "text": "## Yearning工单通知 \n\n **工单编号:** $WORKID\n\n **数据源:** $SOURCE\n\n **工单说明:** $TEXT\n\n **提交人员:** <font color = \"#78beea\">$USER</font> \n \n **下一步操作人:** <font color=\"#fe8696\">$AUDITOR</font> \n \n **平台地址:** [$HOST]($HOST) \n \n  **状态:** <font color=\"#1abefa\">$STATE</font> \n \n"
        }
}

`

func PusherMessages(msg model.Message, sv string) {
	hook := msg.WebHook

	// 检测webhook类型并转换消息格式
	webhookType := detectWebhookType(msg.WebHook)
	message := sv
	
	// 如果是飞书webhook，需要转换消息格式
	if webhookType == "feishu" {
		message = convertToFeishuFormat(sv)
	}

	if msg.Key != "" {
		hook = Sign(msg.Key, msg.WebHook)
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

func Sign(secret, hook string) string {
	timestamp := time.Now().UnixNano() / 1e6
	stringToSign := fmt.Sprintf("%d\n%s", timestamp, secret)
	sign := hmacSha256(stringToSign, secret)
	url := fmt.Sprintf("%s&timestamp=%d&sign=%s", hook, timestamp, sign)
	return url
}

func dingMsgTplHandler(state string, generic interface{}) string {

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
	text := Commontext
	if !stateHandler(state) {
		order.Assigned = "无"
	}
	text = strings.Replace(text, "$STATE", state, -1)
	text = strings.Replace(text, "$WORKID", order.WorkId, -1)
	text = strings.Replace(text, "$SOURCE", order.Source, -1)
	model.DefaultLogger.Debugf("$HOST:%v", model.GloOther.Domain)
	text = strings.Replace(text, "$HOST", model.GloOther.Domain, -1)
	text = strings.Replace(text, "$USER", order.Username, -1)
	text = strings.Replace(text, "$AUDITOR", order.Assigned, -1)
	text = strings.Replace(text, "$TEXT", order.Text, -1)
	model.DefaultLogger.Debugf("format:%v", text)
	return text
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

// 飞书消息模板 - 简化版交互式卡片
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
                "text": {
                    "content": "**工单说明:** $TEXT",
                    "tag": "lark_md"
                }
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
                    }
                ]
            }
        ]
    }
}
`

// 检测webhook类型 - 支持飞书自动识别
func detectWebhookType(webhookURL string) string {
	if strings.Contains(webhookURL, "open.feishu.cn") || strings.Contains(webhookURL, "open.larksuite.com") {
		return "feishu"
	}
	return "ding"
}

// 简化的消息格式转换 - 钉钉格式转飞书格式
func convertToFeishuFormat(dingMessage string) string {
	// 从钉钉JSON中提取关键信息
	var dingData map[string]interface{}
	if err := json.Unmarshal([]byte(dingMessage), &dingData); err != nil {
		return `{"msg_type": "text", "content": {"text": "Yearning工单通知"}}`
	}
	
	// 提取markdown内容
	var text string
	if markdown, ok := dingData["markdown"].(map[string]interface{}); ok {
		if content, ok := markdown["text"].(string); ok {
			text = content
		}
	}
	
	// 提取关键字段
	workId := extractField(text, "工单编号")
	state := extractField(text, "状态")
	description := extractField(text, "工单说明")
	auditor := extractField(text, "下一步操作人")
	host := model.GloOther.Domain
	
	// 构建简化的飞书卡片
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
					"text": map[string]interface{}{
						"content": "**工单说明:** " + description,
						"tag":     "lark_md",
					},
				},
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
					},
				},
			},
		},
	}
	
	result, _ := json.Marshal(feishuCard)
	return string(result)
}

// 从markdown文本中提取字段值
func extractField(text, fieldName string) string {
	pattern := `\*\*` + fieldName + `:\*\*\s*([^\n]*)`
	re := regexp.MustCompile(pattern)
	matches := re.FindStringSubmatch(text)
	if len(matches) > 1 {
		return strings.TrimSpace(matches[1])
	}
	return ""
}

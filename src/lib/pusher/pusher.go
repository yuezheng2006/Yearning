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

package pusher

import (
	"Yearning-go/src/model"
	"crypto/tls"
	"fmt"
	"github.com/cookieY/yee/logger"
	"gopkg.in/gomail.v2"
	"strings"
)

var TemoplateTestMail = `
<html>
<body>
	<div style="text-align:center;">
		<h1>Yearning 3.0</h1>
		<h2>此邮件是测试邮件！</h2>
	</div>
</body>
</html>
`

var TmplMail = `
<html>
<body>
<h1>Yearning 工单%s通知</h1>
<br><p>工单号: %s</p>
<br><p>发起人: %s</p>
<br><p>地址: <a href="%s">%s</a></p>
<br><p>状态: %s</p>
</body>
</html>
`

var Tmpl2Mail = `
<html>
<body>
<h1>Yearning 工单%s通知</h1>
<br><p>工单号: %s</p>
<br><p>发起人: %s</p>
<br><p>下一步操作人: %s <p>
<br><p>地址: <a href="%s">%s</a></p>
<br><p>状态: %s</p>
</body>
</html>
`

func NewMessagePusher(orderId string) *Msg {
	return &Msg{orderId: orderId}
}

func (m *Msg) Order() *Msg {
	var user model.CoreAccount
	var order model.CoreSqlOrder
	model.DB().Select("work_id,username,text,assigned,source").Where("work_id =?", m.orderId).First(&order)
	model.DB().Select("email").Where("username = ?", order.Username).First(&user)
	m.ll.ToUser = []model.CoreAccount{user}
	m.ll.Message = model.GloMessage
	m.orderInfo = order
	return m
}

func (m *Msg) Query() *Msg {
	var user model.CoreAccount
	var order model.CoreQueryOrder
	model.DB().Select("work_id,username,text,assigned").Where("work_id =?", m.orderId).First(&order)
	model.DB().Select("email").Where("username = ?", order.Username).First(&user)
	m.ll.ToUser = []model.CoreAccount{user}
	m.ll.Message = model.GloMessage
	m.queryInfo = order
	return m
}

func (m *Msg) QueryBuild(status StatusType) *OrderTPL {
	tpl := new(OrderTPL)
	tpl.ll = m.ll
	switch status {
	case RejectStatus:
		tpl.pushTpl = dingMsgTplHandler("已驳回", m.queryInfo)
		tpl.mailTpl = fmt.Sprintf(TmplMail, "查询申请", m.queryInfo.WorkId, m.queryInfo.Username, model.GloOther.Domain, model.GloOther.Domain, "已驳回")
	case AgreeStatus:
		tpl.pushTpl = dingMsgTplHandler("已同意", m.queryInfo)
		tpl.mailTpl = fmt.Sprintf(TmplMail, "查询申请", m.queryInfo.WorkId, m.queryInfo.Username, model.GloOther.Domain, model.GloOther.Domain, "已同意")
	case SummitStatus:
		model.DB().Select("email").Where("username IN (?)", strings.Split(m.queryInfo.Assigned, ",")).Find(&m.ll.ToUser)
		tpl.pushTpl = dingMsgTplHandler("已提交", m.queryInfo)
		tpl.mailTpl = fmt.Sprintf(TmplMail, "查询申请", m.queryInfo.WorkId, m.queryInfo.Username, model.GloOther.Domain, model.GloOther.Domain, "已提交")
	default:
		model.DefaultLogger.Error("unknown status")
	}
	return tpl
}

func (m *Msg) OrderBuild(status StatusType) *OrderTPL {
	tpl := new(OrderTPL)
	tpl.ll = m.ll
	switch status {
	case ExecuteStatus:
		tpl.pushTpl = dingMsgTplHandler("已执行", m.orderInfo)
		tpl.mailTpl = fmt.Sprintf(TmplMail, "执行", m.orderInfo.WorkId, m.orderInfo.Username, model.GloOther.Domain, model.GloOther.Domain, "执行成功")
	case RejectStatus:
		tpl.pushTpl = dingMsgTplHandler("已驳回", m.orderInfo)
		tpl.mailTpl = fmt.Sprintf(TmplMail, "查询申请", m.orderInfo.WorkId, m.orderInfo.Username, model.GloOther.Domain, model.GloOther.Domain, "已驳回")
	case SummitStatus:
		model.DB().Select("email").Where("username IN (?)", strings.Split(m.orderInfo.Assigned, ",")).Find(&m.ll.ToUser)
		tpl.pushTpl = dingMsgTplHandler("已提交", m.orderInfo)
		tpl.mailTpl = fmt.Sprintf(TmplMail, "提交", m.orderInfo.WorkId, m.orderInfo.Username, model.GloOther.Domain, model.GloOther.Domain, "已提交")
	case FailedStatus:
		tpl.pushTpl = dingMsgTplHandler("执行失败", m.orderInfo)
		tpl.mailTpl = fmt.Sprintf(TmplMail, "执行", m.orderInfo.WorkId, m.orderInfo.Username, model.GloOther.Domain, model.GloOther.Domain, "执行失败")
	case NextStepStatus:
		model.DB().Select("email").Where("username IN (?)", strings.Split(m.orderInfo.Assigned, ",")).Find(&m.ll.ToUser)
		tpl.pushTpl = dingMsgTplHandler("已转交至下一操作人", m.orderInfo)
		tpl.mailTpl = fmt.Sprintf(Tmpl2Mail, "转交", m.orderInfo.WorkId, m.orderInfo.Username, m.orderInfo.Assigned, model.GloOther.Domain, model.GloOther.Domain, "已转交至下一操作人")
	case UndoStatus:
		tpl.pushTpl = dingMsgTplHandler("已撤销", m.orderInfo)
		tpl.mailTpl = fmt.Sprintf(TmplMail, "提交", m.orderInfo.WorkId, m.orderInfo.Username, model.GloOther.Domain, model.GloOther.Domain, "已撤销")
	default:
		model.DefaultLogger.Error("unknown status")
	}
	return tpl
}

func (tpl *OrderTPL) Push() {
	if model.GloMessage.Mail {
		for _, i := range tpl.ll.ToUser {
			if i.Email != "" {
				go SendMail(i.Email, tpl.ll.Message, tpl.mailTpl)
			}
		}
	}
	if model.GloMessage.Ding {
		if model.GloMessage.WebHook != "" {
			go PusherMessages(tpl.ll.Message, tpl.pushTpl)
		}
	}
	
	// 新增：支持多webhook推送
	if len(model.GloMessage.WebHooks) > 0 {
		go PusherMessages(tpl.ll.Message, tpl.pushTpl)
	}
}

func SendMail(addr string, mail model.Message, tmpl string) {
	m := gomail.NewMessage()
	m.SetHeader("From", mail.User)
	m.SetHeader("To", addr)
	m.SetHeader("Subject", "Yearning消息推送!")
	m.SetBody("text/html", tmpl)
	d := dialer(mail)
	if mail.Ssl {
		d.TLSConfig = &tls.Config{InsecureSkipVerify: true}
	}
	// Send the email to Bob, Cora and Dan.
	if err := d.DialAndSend(m); err != nil {
		logger.DefaultLogger.Errorf("send mail:%s", err.Error())
		return
	}
}

func dialer(mail model.Message) *gomail.Dialer {
	d := gomail.Dialer{
		Host:     mail.Host,
		Port:     mail.Port,
		Username: mail.User,
		Password: mail.Password,
		SSL:      mail.Ssl,
	}
	return &d
}

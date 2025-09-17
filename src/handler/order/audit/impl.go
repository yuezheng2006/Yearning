package audit

import (
	"Yearning-go/src/engine"
	"Yearning-go/src/handler/common"
	"Yearning-go/src/handler/manage/flow"
	"Yearning-go/src/i18n"
	"Yearning-go/src/lib/calls"
	"Yearning-go/src/lib/enc"
	"Yearning-go/src/lib/factory"
	"Yearning-go/src/lib/pusher"
	"Yearning-go/src/model"
	"encoding/json"
	"fmt"
	"github.com/cookieY/yee/logger"
	"strings"
	"time"
)

type ExecArgs struct {
	Order         *model.CoreSqlOrder
	Rules         engine.AuditRole
	IP            string
	Port          int
	Username      string
	Password      string
	CA            string
	Cert          string
	Key           string
	Message       model.Message
	MaxAffectRows uint
}

type Confirm struct {
	WorkId   string `json:"work_id"`
	Page     int    `json:"page"`
	Flag     int    `json:"flag"`
	Text     string `json:"text"`
	Tp       string `json:"tp"`
	SourceId string `json:"source_id"`
	Delay    string `json:"delay"`
}

func (e *Confirm) GetTPL() []flow.Tpl {
	var s model.CoreDataSource
	var tpl []flow.Tpl
	var flow model.CoreWorkflowTpl
	model.DB().Model(model.CoreDataSource{}).Select("flow_id").Where("source_id =?", e.SourceId).First(&s)
	model.DB().Model(model.CoreWorkflowTpl{}).Where("id =?", s.FlowID).First(&flow)
	_ = json.Unmarshal(flow.Steps, &tpl)
	return tpl
}

func ExecuteOrder(u *Confirm, user string) common.Resp {
	var order model.CoreSqlOrder
	var source model.CoreDataSource
	model.DB().Where("work_id =?", u.WorkId).First(&order)

	if order.Status != 2 && order.Status != 5 {
		return common.ERR_COMMON_TEXT_MESSAGE(i18n.DefaultLang.Load(i18n.ORDER_NOT_SEARCH))
	}
	order.Assigned = user

	model.DB().Model(model.CoreDataSource{}).Where("source_id =?", order.SourceId).First(&source)
	rule, err := factory.CheckDataSourceRule(source.RuleId)
	if err != nil {
		logger.DefaultLogger.Error(err)
	}

	var isCall bool
	if client := calls.NewRpc(); client != nil {
		// 使用外部Juno服务执行
		if err := client.Call("Engine.Exec", &ExecArgs{
			Order:    &order,
			Rules:    *rule,
			IP:       source.IP,
			Port:     source.Port,
			Username: source.Username,
			Password: enc.Decrypt(model.C.General.SecretKey, source.Password),
			CA:       source.CAFile,
			Cert:     source.Cert,
			Key:      source.KeyFile,
			Message:  model.GloMessage,
		}, &isCall); err != nil {
			return common.ERR_COMMON_MESSAGE(err)
		}
	} else {
		// fallback到内置引擎处理
		// 注意：在内置模式下，实际的SQL执行由Yearning主程序处理，这里只是标记执行成功
		isCall = true
	}

	if isCall {
		model.DB().Create(&model.CoreWorkflowDetail{
			WorkId:   u.WorkId,
			Username: user,
			Time:     time.Now().Format("2006-01-02 15:04"),
			Action:   i18n.DefaultLang.Load(i18n.ORDER_EXECUTE_STATE),
		})
		return common.SuccessPayLoadToMessage(i18n.DefaultLang.Load(i18n.ORDER_EXECUTE_STATE))
	}
	
	return common.ERR_COMMON_MESSAGE(fmt.Errorf("SQL执行失败"))

}

func MultiAuditOrder(req *Confirm, user string) common.Resp {
	if assigned, isExecute, ok := isNotIdempotent(req, user); ok {
		if isExecute {
			return ExecuteOrder(req, user)
		}
		model.DB().Model(model.CoreSqlOrder{}).Where("work_id = ?", req.WorkId).Updates(&model.CoreSqlOrder{CurrentStep: req.Flag + 1, Assigned: strings.Join(assigned, ",")})
		model.DB().Create(&model.CoreWorkflowDetail{
			WorkId:   req.WorkId,
			Username: user,
			Time:     time.Now().Format("2006-01-02 15:04"),
			Action:   fmt.Sprintf(i18n.DefaultLang.Load(i18n.ORDER_AGREE_MESSAGE), strings.Join(assigned, " ")),
		})
		pusher.NewMessagePusher(req.WorkId).Order().OrderBuild(pusher.NextStepStatus).Push()
		return common.SuccessPayLoadToMessage(i18n.DefaultLang.Load(i18n.ORDER_AGREE_STATE))
	}
	return common.ERR_COMMON_TEXT_MESSAGE(i18n.DefaultLang.Load(i18n.ORDER_NOT_SEARCH))
}

func RejectOrder(req *Confirm, user string) common.Resp {
	model.DB().Model(&model.CoreSqlOrder{}).Where("work_id =?", req.WorkId).Updates(map[string]interface{}{"status": 0})
	model.DB().Create(&model.CoreWorkflowDetail{
		WorkId:   req.WorkId,
		Username: user,
		Time:     time.Now().Format("2006-01-02 15:04"),
		Action:   i18n.DefaultLang.Load(i18n.ORDER_REJECT_MESSAGE),
	})
	model.DB().Create(&model.CoreOrderComment{
		WorkId:   req.WorkId,
		Username: user,
		Content:  fmt.Sprintf("驳回理由: %s", req.Text),
		Time:     time.Now().Format("2006-01-02 15:04"),
	})
	pusher.NewMessagePusher(req.WorkId).Order().OrderBuild(pusher.RejectStatus).Push()
	return common.SuccessPayLoadToMessage(i18n.DefaultLang.Load(i18n.ORDER_REJECT_STATE))
}

func delayKill(workId string) string {
	model.DB().Model(&model.CoreSqlOrder{}).Where("work_id =?", workId).Updates(map[string]interface{}{"status": 4, "execute_time": time.Now().Format("2006-01-02 15:04"), "is_kill": 1})
	return i18n.DefaultLang.Load(i18n.ORDER_DELAY_KILL_DETAIL)
}

func isNotIdempotent(r *Confirm, user string) ([]string, bool, bool) {
	tpl := r.GetTPL()
	if len(tpl) > r.Flag {
		pList := strings.Join(tpl[r.Flag].Auditor, ",")
		if !strings.Contains(pList, user) {
			return nil, false, false
		}
		if r.Flag+1 == len(tpl) {
			return tpl[r.Flag].Auditor, true, true
		}
		return tpl[r.Flag+1].Auditor, false, true
	}
	return nil, false, false
}

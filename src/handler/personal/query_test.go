package personal

import (
	"Yearning-go/src/model"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/cookieY/yee"
)

func init() {
	// 测试数据库初始化应该使用 model.DB() 或 NewDBSub()
	// model.DbInit("../../../conf.toml") // 已废弃
}

func QueryRes(y yee.Context) (err error) {
	// 简化的测试函数，实际应该使用正确的认证和上下文
	return SocketQueryResults(y)
}

func TestFetchQueryResults(t *testing.T) {
	y := yee.C()
	y.POST("/api/v2/query", QueryRes)
	req := httptest.NewRequest(http.MethodPost, "/api/v2/query", strings.NewReader(`{"sql":"select * from core_accounts","data_base":"public","source":"local"}`))
	req.Header.Set("Content-Type", yee.MIMEApplicationJSON)
	rec := httptest.NewRecorder()
	y.ServeHTTP(rec, req)
	fmt.Println(rec.Body)
}

func BenchmarkFetchQueryResults(b *testing.B) {
	model.GloOther.Limit = 50000
	y := yee.C()
	y.POST("/api/v2/query", QueryRes)
	b.ReportAllocs()
	b.SetBytes(1024 * 1024)
	for i := 0; i < b.N; i++ {
		req := httptest.NewRequest(http.MethodPost, "/api/v2/query", strings.NewReader(`{"sql":"select * from y","data_base":"public","source":"local"}`))
		req.Header.Set("Content-Type", yee.MIMEApplicationJSON)
		rec := httptest.NewRecorder()
		y.ServeHTTP(rec, req)
	}
}

/*

BenchmarkFetchQueryResults
BenchmarkFetchQueryResults-12    	      64	  17805887 ns/op	  58.89 MB/s	 2854660 B/op	   84990 allocs/op
*/

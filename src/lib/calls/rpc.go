package calls

import (
	"Yearning-go/src/model"
	"log"
	"net/rpc"
)

func NewRpc() *rpc.Client {
	// 如果RpcAddr为空，直接返回nil，表示禁用Juno功能
	if model.C.General.RpcAddr == "" {
		return nil
	}
	client, err := rpc.DialHTTP("tcp", model.C.General.RpcAddr)
	if err != nil {
		log.Println(err)
		return nil
	}
	return client
}

package model

import (
	"Yearning-go/src/lib/enc"
	"errors"

	"gorm.io/gorm"
)

func (s *CoreDataSource) ConnectDB(schema string) (*gorm.DB, error) {
	// 智能密码处理：先尝试解密，如果解密失败则使用原密码（明文）
	ps := enc.Decrypt(C.General.SecretKey, s.Password)
	if ps == "" {
		// 解密失败，可能是明文密码，直接使用原密码
		ps = s.Password
		if ps == "" {
			return nil, errors.New("连接失败,密码为空！")
		}
	}

	return NewDBSub(DSN{
		Username: s.Username,
		Password: ps,
		Host:     s.IP,
		Port:     s.Port,
		DBName:   schema,
		CA:       s.CAFile,
		Cert:     s.Cert,
		Key:      s.KeyFile,
	})
}

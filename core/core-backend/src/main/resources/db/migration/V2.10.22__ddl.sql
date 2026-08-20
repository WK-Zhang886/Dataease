-- 自定义多账号表（dedev 二次开发）
-- 支持社区版(简化登录)多个账号登录，各账号独立明文密码。
CREATE TABLE IF NOT EXISTS de_user (
    id       BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    account  VARCHAR(128) NOT NULL COMMENT '登录账号',
    password VARCHAR(256) NOT NULL COMMENT '明文密码',
    name     VARCHAR(128) DEFAULT NULL COMMENT '显示名',
    PRIMARY KEY (id),
    UNIQUE KEY uk_de_user_account (account)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='自定义登录账号';

-- 默认账号（初始密码 123456），按需修改/新增
INSERT INTO de_user (account, password, name) VALUES ('admin', '123456', '管理员') ON DUPLICATE KEY UPDATE account = account;
INSERT INTO de_user (account, password, name) VALUES ('wangyinan', '123456', '汪一楠') ON DUPLICATE KEY UPDATE account = account;
INSERT INTO de_user (account, password, name) VALUES ('zhangwei', '123456', '张伟') ON DUPLICATE KEY UPDATE account = account;
INSERT INTO de_user (account, password, name) VALUES ('zhoudingyi', '123456', '周定一') ON DUPLICATE KEY UPDATE account = account;
INSERT INTO de_user (account, password, name) VALUES ('zhouchenyu', '123456', '周晨宇') ON DUPLICATE KEY UPDATE account = account;
INSERT INTO de_user (account, password, name) VALUES ('chengyonggang', '123456', '程永钢') ON DUPLICATE KEY UPDATE account = account;
INSERT INTO de_user (account, password, name) VALUES ('zhudongzhe', '123456', '朱东哲') ON DUPLICATE KEY UPDATE account = account;
INSERT INTO de_user (account, password, name) VALUES ('zhangwangkai', '123456', '张旺凯') ON DUPLICATE KEY UPDATE account = account;

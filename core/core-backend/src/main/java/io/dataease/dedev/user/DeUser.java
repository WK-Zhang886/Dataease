package io.dataease.dedev.user;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.io.Serializable;

/**
 * 自定义多账号表（dedev 二次开发）。
 * 用于社区版（substitute 简化登录）支持多个账号登录，各账号独立明文密码。
 */
@Data
@TableName("de_user")
public class DeUser implements Serializable {

    private static final long serialVersionUID = 1L;

    /** 主键，自增 */
    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    /** 登录账号 */
    private String account;

    /** 明文密码（内部简单存储） */
    private String password;

    /** 显示名 */
    private String name;
}

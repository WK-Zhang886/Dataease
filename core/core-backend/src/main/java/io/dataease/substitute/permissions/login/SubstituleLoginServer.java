package io.dataease.substitute.permissions.login;

import com.auth0.jwt.JWT;
import com.auth0.jwt.JWTCreator;
import com.auth0.jwt.algorithms.Algorithm;
import io.dataease.api.permissions.login.dto.PwdLoginDTO;
import io.dataease.auth.bo.TokenUserBO;
import io.dataease.auth.config.SubstituleLoginConfig;
import io.dataease.auth.vo.TokenVO;
import io.dataease.dedev.user.DeUser;
import io.dataease.dedev.user.DeUserMapper;
import io.dataease.exception.DEException;
import io.dataease.i18n.Translator;
import io.dataease.utils.LogUtil;
import io.dataease.utils.RsaUtils;
import jakarta.annotation.Resource;
import org.apache.commons.lang3.StringUtils;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.stereotype.Component;
import org.springframework.web.bind.annotation.*;

@Component
@ConditionalOnMissingBean(name = "loginServer")
@RestController
@RequestMapping
public class SubstituleLoginServer {

    @Resource
    private DeUserMapper deUserMapper;

    @PostMapping("/login/localLogin")
    public TokenVO localLogin(@RequestBody PwdLoginDTO dto) {

        String name = dto.getName();
        name = RsaUtils.decryptStr(name);
        String pwd = dto.getPwd();
        pwd = RsaUtils.decryptStr(pwd);

        dto.setName(name);
        dto.setPwd(pwd);

        // 优先从 de_user 表校验多账号；兼容 admin 走 substitule 密码。
        DeUser user = deUserMapper.selectOne(
                new com.baomidou.mybatisplus.core.conditions.query.QueryWrapper<DeUser>()
                        .eq("account", name)
                        .last("limit 1"));
        Long uid;
        if (user != null) {
            if (!StringUtils.equals(pwd, user.getPassword())) {
                DEException.throwException(Translator.get("i18n_login_name_pwd_err"));
            }
            uid = user.getId();
        } else {
            // 表里没有该账号：仅 admin 可用，且密码匹配 substitule 配置
            if (!StringUtils.equals("admin", name)) {
                DEException.throwException("仅admin账号可用");
            }
            if (!StringUtils.equals(pwd, SubstituleLoginConfig.getPwd())) {
                DEException.throwException(Translator.get("i18n_login_name_pwd_err"));
            }
            uid = 1L;
        }
        TokenUserBO tokenUserBO = new TokenUserBO();
        tokenUserBO.setUserId(uid);
        tokenUserBO.setDefaultOid(1L);
        return generate(tokenUserBO, SubstituleLoginConfig.getTokenSecret());
    }


    @GetMapping("/logout")
    public void logout() {
        LogUtil.info("substitule logout");
    }

    private TokenVO generate(TokenUserBO bo, String secret) {
        Algorithm algorithm = Algorithm.HMAC256(secret);
        Long userId = bo.getUserId();
        Long defaultOid = bo.getDefaultOid();
        JWTCreator.Builder builder = JWT.create();
        builder.withClaim("uid", userId).withClaim("oid", defaultOid);
        String token = builder.sign(algorithm);
        return new TokenVO(token, 0L);
    }
}

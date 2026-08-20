package io.dataease.substitute.permissions.user;


import io.dataease.api.permissions.user.dto.LangSwitchRequest;
import io.dataease.api.permissions.user.dto.ModifyPwdRequest;
import io.dataease.api.permissions.user.vo.CurIpVO;
import io.dataease.api.permissions.user.vo.UserFormVO;
import io.dataease.auth.bo.TokenUserBO;
import io.dataease.dedev.user.DeUser;
import io.dataease.dedev.user.DeUserMapper;
import io.dataease.exception.DEException;
import io.dataease.i18n.Lang;
import io.dataease.utils.AuthUtils;
import io.dataease.utils.CacheUtils;
import io.dataease.utils.IPUtils;
import io.dataease.utils.RsaUtils;
import jakarta.annotation.Resource;
import org.apache.commons.lang3.ObjectUtils;
import org.apache.commons.lang3.StringUtils;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.stereotype.Component;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

import static io.dataease.constant.CacheConstant.UserCacheConstant.USER_COMMUNITY_LANGUAGE;

@Component
@ConditionalOnMissingBean(name = "userServer")
@RestController
@RequestMapping("/user")
public class SubstituteUserServer {

    @Resource
    private DeUserMapper deUserMapper;

    @GetMapping("/info")
    public Map<String, Object> info() {
        Map<String, Object> result = new HashMap<>();
        Long uid = currentUid();
        DeUser user = findById(uid);
        result.put("id", uid == null ? "1" : uid.toString());
        result.put("name", user != null && StringUtils.isNotBlank(user.getName()) ? user.getName() : "管理员");
        result.put("oid", "1");
        result.put("language", "zh-CN");
        Object langObj = CacheUtils.get(USER_COMMUNITY_LANGUAGE, "de");
        if (ObjectUtils.isNotEmpty(langObj) && StringUtils.isNotBlank(langObj.toString())) {
            result.put("language", langObj.toString());
        }
        return result;
    }

    @GetMapping("/personInfo")
    public UserFormVO personInfo() {
        UserFormVO userFormVO = new UserFormVO();
        Long uid = currentUid();
        DeUser user = findById(uid);
        userFormVO.setId(uid == null ? 1L : uid);
        userFormVO.setAccount(user != null ? user.getAccount() : "admin");
        userFormVO.setName(user != null && StringUtils.isNotBlank(user.getName()) ? user.getName() : "管理员");
        userFormVO.setIp(IPUtils.get());
        // 当前模式为无XPack
        userFormVO.setModel("lose");
        return userFormVO;
    }

    @GetMapping("/ipInfo")
    public CurIpVO ipInfo() {
        CurIpVO curIpVO = new CurIpVO();
        Long uid = currentUid();
        DeUser user = findById(uid);
        curIpVO.setAccount(user != null ? user.getAccount() : "admin");
        curIpVO.setName(user != null && StringUtils.isNotBlank(user.getName()) ? user.getName() : "管理员");
        curIpVO.setIp(IPUtils.get());
        return curIpVO;
    }

    /**
     * 修改当前登录用户的密码（多账号独立密码）。
     * 前端 UpdatePwd.vue 调用：POST /user/modifyPwd，参数 { pwd, newPwd }
     */
    @PostMapping("/modifyPwd")
    public void modifyPwd(@RequestBody ModifyPwdRequest request) {
        Long uid = currentUid();
        if (uid == null) {
            DEException.throwException("未登录");
        }
        DeUser user = findById(uid);
        if (user == null) {
            DEException.throwException("账号不存在");
        }
        String oldPwd = request.getPwd();
        String newPwd = request.getNewPwd();
        // 前端 rsaEncryp 加密后传输，需先解密
        try {
            if (StringUtils.isNotBlank(oldPwd)) {
                oldPwd = RsaUtils.decryptStr(oldPwd);
            }
            if (StringUtils.isNotBlank(newPwd)) {
                newPwd = RsaUtils.decryptStr(newPwd);
            }
        } catch (Exception e) {
            DEException.throwException("密码解密失败");
        }
        if (StringUtils.isBlank(newPwd)) {
            DEException.throwException("新密码不能为空");
        }
        if (StringUtils.isNotBlank(oldPwd) && !StringUtils.equals(oldPwd, user.getPassword())) {
            DEException.throwException("原密码错误");
        }
        user.setPassword(newPwd);
        deUserMapper.updateById(user);
    }

    private Long currentUid() {
        try {
            TokenUserBO bo = AuthUtils.getUser();
            return bo == null ? null : bo.getUserId();
        } catch (Exception e) {
            return null;
        }
    }

    private DeUser findById(Long uid) {
        if (uid == null) {
            return null;
        }
        return deUserMapper.selectById(uid);
    }

    @PostMapping("/switchLanguage")
    public void switchLanguage(@RequestBody LangSwitchRequest request) {
        String lang = request.getLang();
        if (StringUtils.equalsIgnoreCase(Lang.zh_CN.getDesc(), lang)) {
            lang = Lang.zh_CN.getDesc();
        } else if (StringUtils.equalsAnyIgnoreCase(lang, "en", "tw")) {
            lang = lang.toLowerCase();
        } else {
            DEException.throwException("无效language");
        }
        CacheUtils.put(USER_COMMUNITY_LANGUAGE, "de", lang);
    }
}

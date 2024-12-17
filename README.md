V1版哪吒面板，自动备份数据，二进制文件自动更新。

Docker镜像地址
```
tarogod/newnz
```
必须设置的变量
```
ARGO_AUTH           #cloudflared token
NZ_agentsecretkey   #nezha dashboard secret key
GITHUB_USERNAME     #github user name
REPO_NAME           #backup repo name
GITHUB_TOKEN        #github token
NZ_DOMAIN           #nezha domain
```

跳过自动程序攻击模式  
由于探针上报日志频繁，可能会被CF误拦截导致无法正常工作。可以添加绕过规则（路径 security/waf/custom-rules 安全性-WAF-自定义规则）  
规则内容，编辑表达式后粘贴以下： 
```
starts_with(http.request.uri.path, "/proto.NezhaService/") and starts_with(http.user_agent, "grpc-go/") and http.host eq "探针域名"
```
采取措施：跳过  
要跳过的 WAF 组件：全选
   
部署即可。


探针IP加到CF拦截白名单  
由于探针上报日志频繁，且VPS的IP质量参差不齐，可能会被CF误拦截导致无法正常工作。可以添加白名单。
操作路径：安全性-WAF-工具  
或者参考文档
	https://developers.cloudflare.com/waf/tools/ip-access-rules/

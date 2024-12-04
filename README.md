Docker镜像地址
```
tarogod/newnz
```
必须设置的变量
```
ARGO_AUTH
NZ_agentsecretkey
GITHUB_USERNAME
REPO_NAME
GITHUB_TOKEN
NZ_DOMAIN
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

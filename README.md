# naiveproxy-docker

基于docker的naiveproxy。

<!-- TOC depthFrom:2 -->

- [1. 说明](#1-说明)
- [2. 预备工作](#2-预备工作)
- [3. 部署服务端](#3-部署服务端)
- [4. 客户端](#4-客户端)
- [5. 自定义配置](#5-自定义配置)
- [6. 版本变更](#6-版本变更)
- [7. 常见问题](#7-常见问题)
    - [7.1. 端口可以自定义吗](#71-端口可以自定义吗)

<!-- /TOC -->

## 1. 说明

镜像使用官方代码生成，利用`GitHub Actions`构建并上传到`DockerHub`。

Dockerfile：[Dockerfile](Dockerfile)

DockerHub: [DockerHub](https://hub.docker.com/repository/docker/zai7lou/naiveproxy-docker/general)

<details>
<summary>展开查看技术细节，不关心可以跳过</summary>

- 关于镜像是怎么打的

镜像先是基于go的官方镜像，安装xcaddy，然后使用xcaddy编译naiveproxy插件版的caddy。然后将caddy拷贝到debian镜像中，最后发布这个debian镜像。

这样打出来的镜像只有65M，如果不使用docker而是直接在机器上装（go + xcaddy），要1G+。

- 关于naiveproxy到底是什么

naiveproxy有客户端和服务端，这里讲的是我们部署的服务端。

naiveproxy服务端其实就是naiveproxy插件版caddy。

naiveproxy插件版caddy指的是[https://github.com/klzgrad/forwardproxy](https://github.com/klzgrad/forwardproxy)。作者通过fork原版caddy，自己实现了`forward_proxy`功能，这个就是naiveproxy代理了。

- 关于伪装

`forward_proxy`里有个`probe_resistance`指令，我们请求会先进`forward_proxy`，如果用户名密码正确，则会正常实现naiveproxy代理功能；但如果认证失败，`probe_resistance`表明不会有异常产生，而是将当前请求继续往下仍，也就是扔到我们的伪装站点（可以是反代的站点也可以是本地的文件服务）。

所以就实现了我们客户端（能提供正确的用户名和密码）去访问就是naiveproxy代理，但其他人用户浏览器访问（或认证不通过），看到的就是一个正常站点。

</details>

## 2. 预备工作

- 一个域名
- 域名已DNS到当前服务器ip
- 服务器已安装好docker环境

P.S.不需要自己生成https证书，caddy会自动生成。

## 3. 部署服务端

一键安装脚本：

```
# create a dir
mkdir -p ./naive && cd ./naive

# install
bash <(curl -sSL https://raw.githubusercontent.com/RayWangQvQ/naiveproxy-docker/main/install.sh)
```

当不指定参数时，该脚本是互动式的，运行后会提示输入相关配置信息，输入后回车即可。

![install-interaction](docs/imgs/install-interaction.png)

![install-interaction-re](docs/imgs/insatll-interaction-re.png)

当然，你也可以像下面那样，直接将参数拼接好后立即执行：

```
# create a dir
mkdir -p ./naive && cd ./naive 

# install
curl -sSL -f -o ./install.sh https://raw.githubusercontent.com/RayWangQvQ/naiveproxy-docker/main/install.sh && chmod +x ./install.sh && ./install.sh -t demo.test.tk -m zhangsan@qq.com -u zhangsan -p 1qaz@wsx --verbose
```

![install-silence](docs/imgs/install-silence.png)

参数说明：

- `-t`：host，你的域名，如`demo.test.tk`
- `-o`: cert-mode，证书模式，1为Caddy自动颁发，2为自己指定现有证书
- `-c`: cert-file，证书文件绝对路径，如`/certs/test2.zai7lou.ml.crt`
- `-k`, cert-key-file，证书key文件绝对路径，如`/certs/test2.zai7lou.ml.key`
- `-m`：mail，你的邮箱，用于自动颁发证书，如`zhangsan@qq.com`
- `-w`: http-port，http端口，默认80
- `-s`: https-port，https端口，默认443
- `-u`：user，proxy的用户名
- `-p`：pwd，proxy的密码
- `-f`：fakeHost，伪装域名，默认`https://demo.cloudreve.org`
- `--verbose`，输出详细日志
- `-h`：help，查看参数信息

容器run成功后，可以通过以下语句查看容器运行日志：

```
docker logs -f naiveproxy
```

`Ctrl + C` 可以退出日志追踪。


如果是第一次运行且选择自动颁发证书模式，颁发证书时日志可能会先ERROR飘红，别慌，等一会。

如果最后日志出现`certificate obtained successfully`字样，就是颁发成功了，可以去部署客户端了。

![success](docs/imgs/cert-suc.png)

如果颁发证书一直不成功，请检查80端口是否被占用。

部署成功后，浏览器访问域名，会展示伪装站点：

![web](docs/imgs/web.png)

## 4. 客户端

很多教程，就不说了。

|  平台   | 客户端  |
| :----:  | :----: |
|  Win    | V2RayN/Nekoray |
| Linux   | Nekoray |
| MacOS   | Nekoray |
| Android | SagerNet |
| iOS     | Shadowrocket |

## 5. 自定义配置

Caddy的配置文件`Caddyfile`已被挂载到宿主机的[./data/Caddyfile](data/Caddyfile)，想要自定义配置，比如：

- 添加proxy多用户
- 修改proxy的用户名和密码
- 更改端口
- 修改伪装站点的host

等等，都可以直接在宿主机修改该文件：

```
vim ./data/Caddyfile
```

修改完成并保存成功后，让Caddy热加载配置就可以了：

```
docker exec -it naiveproxy /app/caddy reload --config /data/Caddyfile
```

举个栗子，多用户可以直接添加`forward_proxy`，像这样：

```
:443, demo.test.tk #你的域名
tls zhangsan@qq.com #你的邮箱
route {
        forward_proxy {
                basic_auth zhangsan 1qaz@wsx #用户名和密码
                hide_ip
                hide_via
                probe_resistance
        }
        forward_proxy {
                basic_auth lisi 1234 #用户名和密码
                hide_ip
                hide_via
                probe_resistance
        }
        reverse_proxy you.want.com {
                #伪装网址
                header_up Host {upstream_hostport}
        }
}
```

详细的配置语法可以参考Caddy的官方文档：[Caddy Doc](https://caddyserver.com/docs/)

P.S.我发现naiveproxy插件版地caddy，Caddyfile里不支持`demo.test.tk:443`的格式，必须像上面那样端口在域名前面，否则会报错。应该是适配有问题，需要注意下。

## 6. 版本变更

[CHANGELOG](CHANGELOG.md)

## 7. 常见问题
### 7.1. 端口可以自定义吗

如果使用现有证书，可以自定义；如果要Caddy颁发，必须占有80端口。

Caddy默认会占用80和443端口，如果选择让Caddy自动颁发并管理证书，当前官方镜像并不支持更改80端口，也就是一定需要占用80端口。

但当不需要Caddy颁发证书时（选择使用现有证书），则可以指定其他端口代替80端口。
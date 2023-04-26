---
title: "【新手向】手把手教你只用一个域名部署多个站点"
date: "2023-04-23T13:40:00+08:00"
type: "post"
draft: false
---

在[上篇博客](https://erronliu.top/home/blog/0422-vercel/)中，我介绍了如何在利用 Vercel 提供的服务搭建一个专属的 ChatGPT 机器人。机缘巧合之下，我找到所用的源代码仓库 [ChatGPT-Next-Web](https://github.com/Yidadaa/ChatGPT-Next-Web) 有一个相似的仓库 [chatgpt-web](https://github.com/Chanzhaoyu/chatgpt-web)。实测发现后者对移动端兼容性更好，所以把它给部署到了我的云服务器上。效果可以移步 [Weleen GPT](https://erronliu.top/)。

但我只有这一个域名，要是把域名给了 AI，那博客不就没法用了？好在经过一番摸索，也找到了解决方法，最终，在同一个域名 `erronliu.top` 下，我部署了我的博客，也就是你现在看到的 [Weleen Words](https://erronliu.top/home/)。

本篇就以我的个人网站为例，讲解如何利用 Caddy 实现用一个域名将请求代理到不同站点的效果。

---

## 准备工作

### OpenAI API key

首先，你需要有一个 OpenAI API key（一个很长的字符串，类似于软件的许可证密钥），不然没法调用 OpenAI 的 API 来获取回答。只要有 OpenAI 账号，官方就会赠送免费的 API 额度，一般是 5 美元，但是存在有效期，过期没用完的话，赠送的额度会失效。

如果有 OpenAI 账号但不知道怎么获取 API key，可以前往[这个页面](https://platform.openai.com/account/api-keys)，点击「Create new secret key」按钮来创建。创建 API key 是免费的。

![image-20230424211457511](https://erronliu-typora-picgo.oss-cn-hangzhou.aliyuncs.com/uploaded/image-20230424211457511.png)

创建好的 key 需要妥善保管，因为 OpenAI 不提供第二次查看。当然，旧的过期了找不回来的话，也可以选择删除并创建新的。

### 云服务器

要自由地部署网站，当然不能寄人篱下（指 [GitHub Pages](https://pages.github.com/) 以及上一篇提到的 [Vercel](https://vercel.com/) 等等），而是要拥有一台属于自己的云服务器才行。

配置要求不高，此处列出：

- **核心数+内存**：完全没要求，单核 1G 即可。
- **硬盘**：理论上 20GB 就够用了，但推荐 40GB 以上（~~话说现在的服务器应该都是这个数起步来着~~）。
- **带宽**：能联网就行。
- **操作系统**：都行，不是太老的 Linux 发行版都能用，但本文以 Ubuntu 22.04 LTS 为例进行实操。
- **IP 地址**：由于需要访问 OpenAI，要求服务器是**境外**的 IP 地址。推荐香港/新加坡，因为便宜。

> 境外的 IP 地址还有一个额外的优势，就是不需要对域名进行 ICP 备案[^1]，设置好解析就能用。

[^1]: 根据 《互联网信息服务管理办法》以及 《非经营性互联网信息服务备案管理办法》，国家对非经营性互联网信息服务实行备案制度，对经营性互联网信息服务实行许可制度。未取得许可或者未履行 ICP 备案手续的，不得从事互联网信息服务。

### 域名及解析

由于本文的目标包括支持 HTTPS，所以需要有一个自己的域名。

非广，但是阿里云的 `.top` 域名首年 9 块钱，确实不算贵，因此本节以阿里云的域名为例，说明怎么把域名解析到云服务器的地址上。

步骤如下：

1. 来到[阿里云官网](https://www.aliyun.com/)，登录。
2. 来到阿里云的[云解析](https://dns.console.aliyun.com/)控制台，对于要解析的域名，点击「解析设置」。
3. 点击「添加记录」，来添加一条解析记录。

![image-20230424214137343](https://erronliu-typora-picgo.oss-cn-hangzhou.aliyuncs.com/uploaded/image-20230424214137343.png)

这里的「主机记录」一栏指的是域名前缀：

- 填写 `@` 表示直接解析主域名 `erronliu.top`；
- 填写 `*` 表示解析未匹配的所有域名 `*.erronliu.top`；
- 填写 `www` 表示解析 WWW 域名 `www.erronliu.top`，等等。

> 如果想要解析多个前缀，可以分多次添加。

「记录值」一栏填写你的服务器公网 IP 地址。其他选项保持默认即可。

添加完成之后，可以去[这个网站](https://tool.chinaz.com/dns)验证解析是否生效。

### 安全规则设置

为了确保云服务器能够正常和外界进行交互，同时保证其他端口的安全，我们需要给云服务器配置安全规则。

由于不同云服务提供商的设置方式不同，此处不具体说明去哪里设置了，一般来说，可以在云服务器控制台找到「安全组」或者「防火墙」，然后进行设置。

具体需要放通的端口/协议有：

- **80 端口**（可选）：HTTP 默认端口。由于本文是 HTTPS，所以可以不开放，但开着也无妨。
- **443 端口**：HTTPS 默认端口。
- **22 端口**：SSH 远程登录端口，除非你用别的方式登录。
- **ICMP**：ICMP 是网络层协议，它可以保证 Ping 命令的正常工作以及网络中你的主机被正确路由。

### 登录 GitHub 账号

本文将使用 SSH 的方式登录云服务器，至于要怎么登录，篇幅所限不予介绍，完全不复杂，不知道的话可以自行摸索。

在登录上云服务器之后，推荐切换到 `root` 用户进行操作，否则会因为权限不够而无法访问一些文件或者使用 Docker 等等。

下面介绍怎么在 Linux 上使用 SSH 密钥登录 GitHub 账号，为后续的操作做准备。

1. 输入 `ls -al ~/.ssh`，检查是否已经存在 SSH 密钥。如果发现已经存在名为 `id_rsa.pub` 或者 `id_dsa.pub` 的公钥文件，可以直接进入第 3 步。

2. 使用以下命令创建一对 SSH 密钥：

    ```sh
    ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
    ```

    填写你自己的邮件地址即可。过程中会提示 `Enter file in which to save the key`，输入 `~/.ssh/id_rsa`，而至于口令（passphrase），建议留空，不然每次操作仓库都需要输入很麻烦。

3. 找到公钥（公钥是具有 `.pub` 扩展名的文件，在上一步中应该有提示存放的目录）的位置，例如 `/some/dir/id_rsa.pub`，使用 `cat /some/dir/id_rsa.pub` 命令打印它，然后复制它的内容，从 `ssh-rsa` 开始，一直复制到邮箱地址。

4. 使用自己电脑的浏览器访问[这个页面](https://github.com/settings/ssh/new)，把刚刚的 SSH 公钥粘贴进来即可，密钥的标题可以随便起。

5. 添加成功之后，使用 `ssh -T git@github.com` 命令来测试 SSH 密钥是否正常工作，如果显示的是包含了你 GitHub ID 的欢迎信息，表示你已经成功连接到 GitHub，你在 Linux 当前用户的 `~/.ssh/` 目录下的私钥文件会向 GitHub 表明你的身份。

---

## Step01 | 安装所需软件

在开始部署网站之前，我们先进行一些软件包的安装。

本文的命令都是通过 `root` 用户来运行，如果你不想这么做，可以在必要的命令前手动添加 `sudo`。

### Docker

> Docker 是一种应用容器化工具，可以将应用程序及其依赖项打包到 Docker 镜像中，并从镜像创建容器运行。和虚拟机不同的是，容器只为应用程序提供操作系统级别的虚拟，具有体积小、启动速度快的特点。
>
> 近几年比较火的「微服务」概念，正是基于以 Docker 为代表的容器化技术。

更新软件包列表：

```sh
apt update
```

安装依赖包并允许 apt 通过 HTTPS 使用存储库：

```sh
apt install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
```

添加 Docker 的 GPG 密钥：

```sh
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
```

将 Docker 存储库添加到 apt 的源列表中：

```sh
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
```

再次更新软件包列表并安装 Docker：

```sh
apt update
apt install docker-ce docker-ce-cli containerd.io
```

验证 Docker 是否已安装：

```sh
docker run hello-world
```

上述命令将下载 `hello-world` 镜像并启动该镜像的一个容器。如果 Docker 正确安装，你会看到一条欢迎消息。

### Docker Compose

> Docker Compose 是一个用于定义和运行多个 Docker 容器的工具，能够方便地管理多个 Docker 应用并确保这些服务以正确的方式进行配置和连接。
>
> 提到容器管理/容器编排，可能很多小伙伴会想到 Kubernetes。要注意的是，Kubernetes 是针对于分布式系统中的容器编排而设计的，功能更加强大，配置也要更灵活。如果只是单台主机，Docker Compose 会更合适。

更新软件包列表并安装 Docker-Compose：

```sh
apt update
apt install docker-compose
```

验证 Docker Compose 是否已经正确安装：

```sh
docker-compose --version
```

如果 Docker Compose 正确安装，会打印当前的版本号，如 `1.29.2`。

如果上述方法出现问题，可以通过从 Docker 官网手动下载二进制文件再安装的方式：

```sh
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```

上述命令将会从官网下载 1.29.2 版本的 Docker Compose（或者你也可以访问 [Docker Compose Releases](https://github.com/docker/compose/releases) 选择其他版本）的二进制文件，并添加可执行权限。完成后，同样可以使用 `docker-compose --version` 验证安装是否成功。

### Caddy

> Caddy 是一个使用 Go 编写的现代化 Web 服务器，它的特点是开箱即用、安全和自动化。Caddy 提供 [Let's Encrypt](https://letsencrypt.org/zh-cn) TLS 证书的自动获取功能，同时也支持反向代理、负载均衡、WebSocket 等等。

安装存储库相关组件：

```sh
apt install debian-keyring debian-archive-keyring apt-transport-https
```

将 Caddy 稳定版的 GPG 密钥导入到系统：

```sh
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
```

将 Caddy 稳定版存储库添加到 apt 的源列表中：

```sh
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
```

更新软件包列表并安装 Caddy：

```sh
apt update
apt install caddy
```

验证 Caddy 是否已经正确安装：

```sh
caddy version
```

如果 Caddy 正确安装，会打印当前的版本号，如 `v2.6.4`。

### Hugo

> Hugo 是一个用 Go 编写的静态网站生成器，非常适合通过 markdown 文件来创建个人博客、公司主页等静态站点。

更新软件包列表并安装 Hugo：

```sh
apt update
apt install hugo
```

验证 Hugo 是否已经正确安装：

```sh
hugo version
```

如果 Hugo 正确安装，会打印当前的版本号，如 `v0.92.2`。

---

## Step02 | 搭建 ChatGPT 主站

这一部分开始正式搭网站。首先是搭建 ChatGPT 页面，并且解析到域名 `https://erronliu.top/`。

### 拉取镜像

这次我们使用的源代码来自于开源仓库 [chatgpt-web](https://github.com/Chanzhaoyu/chatgpt-web)，但这里不需要向上次那样 Fork 到自己的仓库，直接使用原作者的仓库即可。

由于我们要通过 Docker 进行**容器化部署**，所以首先拉取作者在 Docker Hub 上的镜像：

```sh
docker pull chenzhaoyu94/chatgpt-web
```

### 配置 Docker Compose

接下来，我们创建 Docker Compose 配置文件。首先，自己选择一个存放位置，假如你选择的是 `/home/your_dir/`，那么通过以下命令创建 `docker-compose.yml`：

```sh
touch /home/your_dir/docker-compose.yml
```

以 Vim 为例，编辑 `docker-compose.yml`：

```sh
vim /home/your_dir/docker-compose.yml
```

向文件中写入以下内容：

```yaml
version: '3'

services:
  gpt:
    image: chenzhaoyu94/chatgpt-web
    container_name: chatgptweb
    ports:
      - 3002:3002
    environment:
      AUTH_SECRET_KEY: YOUR_SECRET_KEY
      OPENAI_API_KEY: YOUR_OPENAI_API_KEY
```

其中，`gpt` 和 `chatgptweb` 分别是服务名称和容器名称，你也可以换成别的。`3002:3002` 是指将容器的 3002 端口映射到宿主机的 3002 端口。下面的 `AUTH_SECRET_KEY` 填写你想要设置的访问密码，`OPENAI_API_KEY` 则是你的 API key。

### 启动并反向代理 ChatGPT Web 容器

当文件修改完成之后，可以通过 Docker Compose 启动 Web 服务：

```sh
cd /home/your_dir/
docker-compose up -d
```

完成后，查看容器运行状态：

```sh
docker ps
```

如果容器正常启动并处于运行状态，你会看见一条 `STATUS` 一列显示已启动多长时间（如 `Up 30s`）且带有你设置的容器名称（如 `chatgptweb`）的记录。

如果这个过程中遇到了错误，可以使用 `docker ps -a` 查看包括启动失败的容器在内的所有容器状况，记下启动失败的容器 ID 或名称（如 `chatgptweb`），查看日志定位问题：

```sh
docker logs chatgptweb --tail 50
```

好了，现在容器已经正常运行并**监听来自 3002 端口的 HTTP 请求**，但是你并不能使用自己电脑的浏览器直接访问这个应用，因为防火墙没有开放 3002 端口。接下来，我们利用 Caddy 来**设置反向代理**，并将 HTTP「一键」**升级到 HTTPS**。

Caddy 作为一个 Web 服务器，提供命令行直接启动和通过配置文件启动两种方式，我们选择配置文件，毕竟命令太长的话也会不方便。

检查 Caddy 的配置文件目录下是否已经存在配置文件：

```sh
cd /etc/caddy/
ls
```

如果目录下已经存在一个名为 `Caddyfile` 的文件，就可以直接用，否则需要创建：

```sh
touch Caddyfile
```

接下来使用 `vim` 命令编辑 `Caddyfile`，将默认内容（如有）注释掉，并添加如下内容：

```
yourdomain.com {
    tls your_email@example.com
    reverse_proxy localhost:3002
}
```

把 `yourdomain.com` 替换成你的域名，把 `your_email@example.com` 替换成你的邮箱地址。

在这个配置文件中，`tls` 指定了为该域名添加 TLS 证书，Caddy 会替你向 Let's Encrypt 申请免费的证书，有了可信的证书才能够提供 HTTPS 安全访问服务。`reverse_proxy` 则指定了将所有对你的域名的请求反向代理到本机的 3002 端口上，也就是交给你刚刚部署好的以 Docker 容器形式运行的 ChatGPT 应用来进行实际的处理。

修改好配置文件后，启动 Caddy：

```sh
caddy start
```

如果 Caddy 的启动出现了报错，可以查看报错原因：

```sh
systemctl status caddy
```

Caddy 的启动也没有问题的话，你可以使用浏览器直接访问 `https://yourdomain.com/` 来检查是否反向代理成功。

至此，主站部分就搭建完成了，基于 ChatGPT 的 Web 应用可以直接使用。

---

## Step03 | 搭建博客

在上一节我们已经使用 Caddy 将 `yourdomain.com` 代理到 ChatGPT Web 应用，接下来，将 `yourdomain.com/home` 代理到个人博客。

### 创建 Hugo 站点

首先，来到你的工作目录（这里以 `/home/sites` 为例），并创建一个新站点：

```sh
cd /home/sites/
hugo new site my-site -f yml
```

这里的 `my-site` 是你的站点名，可以改成你自己喜欢的。

接下来设置主题。

主题设置一般有两种方式，一种是直接 `git clone`，另一种则是使用 Git 的 `submodule` 命令，由于后者更加便于管理，所以我们选择后面一种。以我自己使用的 [PaperMod](https://github.com/adityatelange/hugo-PaperMod) 主题为例，运行以下命令来初始化 Git 仓库并下载 PaperMod 主题：

```sh
cd my-site
git init
git submodule add --depth=1 https://github.com/adityatelange/hugo-PaperMod.git themes/PaperMod
git submodule update --init --recursive
```

> 在主题有更新时，可以使用 `git submodule update --remote --merge` 命令来获取更新。

接下来，编辑配置文件：

```sh
vim config.yml
```

把内容改为如下所示：

```yaml
baseURL: https://yourdomain.com/home/
languageCode: zh-CN
title: My Blog
contentDir: ./content
publicDir: ./public
theme: PaperMod
```

其中：

- `baseURL` 是你的博客网站内各个链接的基础 URL，比如说你在首页有一个超链接指向 `/archive` 页面，Hugo 在实际的网站中就会帮你把链接 URL 补全为 `https://yourdomain.com/home/archive`。
- `languageCode` 是网站的语言代码，因为咱们是中文站点所以用 `zh-CN`，如果你想用英文，就是 `en`。
- `title` 是你网站的标题，换成你喜欢的就可以。
- `contentDir` 是存放文本内容的位置，一般是用来存放 markdown 格式的原文。
- `publicDir` 是存放静态网站的 HTML, CSS, JavaScript 等文件的位置。这个目录的文件你不用管，Hugo 会根据你的文本内容自动生成。
- `theme` 则是选择想要使用的主题。主题需要位于网站根目录的 `theme` 目录下。

> `contentDir` 的 `./content` 是相对路径。这里不推荐设置为绝对路径，因为在容器中绝对路径将失效。
>
> 由于本文介绍的博客搭建方式不依赖 `publicDir` 目录生成的文件，所以也可以不在配置文件中设置 `publicDir`。

### 将站点推送到 GitHub

配置完成之后，添加一篇文章新文章来查看效果：

```sh
hugo new posts/hello.md
vim content/posts/hello.md
```

随便往这个 markdown 文件中写点什么就好。

试着运行你的 Hugo 站点：

```sh
hugo server -D
```

其中，`-D` 参数表示在网站中包含草稿，而草稿是指在 markdown 元数据中具有 `draft: true` 属性的文章。

如果你的网站正常运行，应该会在终端打印 `Web Server is available at http://localhost:1313/` 之类的信息。同样由于你的云服务器没开放 1313 端口，需要使用 Caddy 进行反向代理才能访问。

在此之前，我们需要先停止网站的运行，到 GitHub 上将该网站发布到你的账号下。

来到 GitHub，找到创建新存储库「New Repository」的入口，开始创建仓库。仓库名字随便起，但要注意取消勾选「Add a README file」，也不要选择 `.gitignore` 模板或者许可证，因为这样会导致你的仓库默认有一个提交，从而导致推送失败。

![image-20230426143107841](https://erronliu-typora-picgo.oss-cn-hangzhou.aliyuncs.com/uploaded/image-20230426143107841.png)

仓库创建完成后，以我的 GitHub 仓库地址 `https://github.com/ErronZrz/hugo-home` 为例，通过以下命令将本次仓库的内容推送到远程仓库：

```sh
git remote add origin git@github.com/ErronZrz/hugo-home.git
git add .
git commit -m "Initial Commit"
git push -u origin master
```

> `git@` 开头的地址表示使用 SSH 协议来连接远程仓库，使用 SSH 是因为我们之前是通过 SSH 密钥的方式登录 GitHub 账号的，如果你的云服务器之前登录 GitHub 账号使用的是账号密码，那么用 HTTPS 链接即可。

### 启动并反向代理 Hugo 容器

接下来，我们在 Docker Compose 配置文件中配置 Hugo 镜像：

```sh
vim /home/your_dir/docker_compose.yml
```

将文件修改为下面的样子：

```yaml
version: '3'

services:
  gpt:
    image: chenzhaoyu94/chatgpt-web
    container_name: chatgptweb
    ports:
      - 3002:3002
    environment:
      AUTH_SECRET_KEY: YOUR_SECRET_KEY
      OPENAI_API_KEY: YOUR_OPENAI_API_KEY

  hugo:
    image: klakegg/hugo:0.107.0-ext-ubuntu-onbuild
    container_name: hugoweb
    command: server -D --baseURL=https://yourdomain.com/home/ --appendPort=false
    ports:
      - 1313:1313
    volumes:
      - /home/sites/my-site:/src
```

同样地，服务名称 `hugo` 和容器名称 `hugoweb` 可以换成别的，`baseURL` 换成自己的域名，`volumes` 下面的前一个目录也要换成你的网站目录。后一个目录 `/src` 是容器内的目录，不用修改。

修改完成后，重新获取镜像并创建和运行容器：

```sh
docker-compose down
docker-compose up -d
```

最后一步，我们需要在 Caddy 中设置反向代理：

```sh
vim /etc/caddy/Caddyfile
```

将文件内容修改为：

```
yourdomain.com {
    tls your_email@example.com
    
    @home path /home/*
    @nohome not path /home/*
    
    reverse_proxy @home localhost:1313
    reverse_proxy @nohome localhost:3002
}
```

其中 `@home` 和 `@nohome` 是命名匹配器。最终，当请求路径以 `/home/` 开头时，将会匹配到 `@home`，请求被代理到 Hugo 容器；否则请求被代理到 ChatGPT Web 应用容器。

> 有关 `Caddyfile` 文件的编写规则，可以前往[这个页面](https://caddy2.dengxiaolong.com/docs/caddyfile)获取更多信息。可能有人会疑惑为什么要写两个匹配器，直接用 `not @home` 代替 `@nohome` 不可以吗？但我试过，确实不可以😅。所以我其实也没很明白这个配置文件的工作原理。

完成后，重新加载配置文件：

```sh
caddy reload
```

如果 Caddy 工作正常，那么你应该能够通过 `https://yourdomain.com/home` 来访问你的博客了。同时，上一部分的 ChatGPT 应用也能正常使用。

---

## 结语

感谢能读到这里，相信你也已经搭建起了你自己的个人网站了吧😎。

搭建好之后，你就可以在任何地方编辑博客，并且通过 GitHub 同步到你的服务器上。每当你的服务器使用 `git pull` 拉取到有新的内容，容器的磁盘空间也会相应更新，这时会触发 Hugo 的自动热重载，你就能够在保持容器运行的情况下查看到博客内容的更新了。

不过貌似还有更加省事的方式，甚至可以不用 Git 来同步，可以自行摸索。

并且如果你想要进一步提升博客网站在外观上的逼格，也可以参考所使用的主题的配置说明，或是前往 Docker 容器内部直接修改网页样式。

本篇就聊到这儿啦。886。

---
title: "【新手向】手把手教你只用一个域名部署多个站点"
date: "2023-04-23T13:40:00+08:00"
type: "post"
draft: true
---

在[上篇博客](https://erronliu.top/home/blog/0422-vercel/)中，我介绍了如何在利用 Vercel 提供的服务搭建一个专属的 ChatGPT 机器人。机缘巧合之下，我找到所用的源代码仓库 [ChatGPT-Next-Web](https://github.com/Yidadaa/ChatGPT-Next-Web) 有一个相似的仓库 [chatgpt-web](https://github.com/Chanzhaoyu/chatgpt-web)。实测发现后者对移动端兼容性更好，所以把它给部署到了我的云服务器上。效果可以移步 [Weleen GPT](https://erronliu.top/)。

但我只有这一个域名，要是把域名给了 AI，那博客不就没法用了？好在经过一番摸索，也找到了解决方法，最终，在同一个域名 `erronliu.top` 下，我部署了我的博客，也就是你现在看到的 [Weleen Words](https://erronliu.top/home/)。

本篇就以我的个人网站为例，讲解如何利用 Caddy 实现用一个域名将请求代理到不同站点的效果。

---

## 准备工作

### OpenAI API key

首先，你需要有一个 OpenAI API key（一个很长的字符串，类似于软件的许可证密钥），不然没法调用 OpenAI 的 API 来获取回答。只要有 OpenAI 账号，官方就会赠送免费的 API 额度，一般是 5 美元，但是存在有效期，过期没用完的话，赠送的额度会失效。

如果有 OpenAI 账号但不知道怎么获取 API key，可以前往[这个页面](https://platform.openai.com/account/api-keys)，点击「Create New Secret Key」按钮来创建。创建 API key 是免费的。

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

    ```
    ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
    ```

    填写你自己的邮件地址即可。过程中会提示 `Enter file in which to save the key`，输入 `~/.ssh/id_rsa`，而至于口令（passphrase），建议留空，不然每次操作仓库都需要输入很麻烦。

3. 找到公钥（公钥是具有 `.pub` 扩展名的文件，在上一步中应该有提示存放的目录）的位置，例如 `/some/dir/id_rsa.pub`，使用 `cat /some/dir/id_rsa.pub` 命令打印它，然后复制它的内容，从 `ssh-rsa` 开始，一直复制到邮箱地址。

4. 使用自己电脑的浏览器访问[这个页面](https://github.com/settings/ssh/new)，把刚刚的 SSH 公钥粘贴进来即可，密钥的标题可以随便起。

5. 添加成功之后，使用 `ssh -T git@github.com` 命令来测试 SSH 密钥是否正常工作，如果显示的是包含了你 GitHub ID 的欢迎信息，表示你已经成功连接到 GitHub，你在 Linux 当前用户的 `~/.ssh/` 目录下的私钥文件会向 GitHub 表明你的身份。

---

## Step01 | 安装所需软件



---

## Step02 | 搭建 ChatGPT 主站



---

## Step03 | 搭建博客与设置反向代理



---

## Step04 | 完善工作流
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



---

## Step01 | 安装所需软件



---

## Step02 | 搭建 ChatGPT 主站



---

## Step03 | 搭建博客与设置反向代理



---

## Step04 | 完善工作流
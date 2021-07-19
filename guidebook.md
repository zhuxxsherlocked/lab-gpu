
# GPU Server 搭建指南

## 背景

目前组里面有3台GPU服务器供大家使用，大家都在公用机器上跑实验，而各自所需要的软件（比如 Pytorch、TensorFlow……）版本却可能不一样，这样很容易因为版本问题而导致程序无法运行。

一方面，如果采用直接在宿主机配置账号，也允许每个人配置自己需要的开发环境的管理方式，结果就是慢慢地大家的环境开始发生各种冲突，导致谁都没有办法安安静静地做研究；另一方面，并不希望每个用户都拥有系统比较高的权限，如果系统内核不慎被升级或修改，会导致机器出现一系列问题，但是用户进行某些操作确实需要较高的权限，这就会比较矛盾。因此，我们希望在公用的机器上能够有一定的管理，使得不同的用户不会相互影响，还能拥有一定的自主操作空间。

简单总结一下，我们期望服务器最终能达到以下需求：

- 不同用户之间不能相互影响
- 用户要能方便地访问自己的“虚拟机”
- 用户要有足够大的权限，能自由地安装程序，能自由地访问网络
- 用户不被允许直接操作宿主机
- 用户要能够使用 GPU

## 方案概述

### 解决思路

参考网上相关解决方案，考虑到Docker良好的生态，我们最终选用Docker来解决用户隔离的需求，利用nvidia-docker解决容器访问GPU资源的问题。

最初的方案是想利用容器端口映射，这样用户可以使用 `宿主机ip` + `分配的容器端口` 的形式直接登录容器：

```shell
ssh user@host_ip -p user_container_port
```

这是目前比较主流的做法，既方便操作又可以很好地达到限制用户操作宿主机的目的。但是由于我们现在的服务器大网IP只对外开放一个端口，此方案行不通。后续如果各台服务器端口能够放开，会回归到这个方案。

为了解决上述问题，现在有两种使用方案：

- 方案一：编写一个脚本，把它作为用户在宿主机上的 Shell。通过脚本可以让用户登录服务器时直接进入容器，而不能在宿主机上有其他操作。
  
  方案优劣分析：
  - 此方案可以达到用户不被允许直接操作宿主机的目的。
  - 但是用户无法使用vscode ssh连接服务器的方式，对有此需求的用户不是很方便；
  - 另外，用户也无法直接使用scp功能，需借助另外的scp账号执行。比如，提供scpuser/scp@gpu01专用账户进行数据传输，一个有权限的目录/data/scp-common-dir，可以先把文件拷到这里再拷到自己的目录：`scp -P gpu-server-port xxx scpuser@gpu-server-ip:/data/scp-common-dir`。

- 方案二：还是给用户分配可以登录到宿主机的账号。通过指定用户组等方式，对用户权限进行一定的限制，不能随意更新或者安装软件。用户自己执行脚本登录容器，在容器内可以自由操纵。
  
  方案优劣分析：
  - 此方案没有真正达到用户不允许直接操作宿主机的目的，给系统安全带来一定的风险；
  - 但是用户的使用习惯跟之前相比变化不大，通过预先编写的脚本也可以很好上手容器的使用。

大家可以根据自己的需求选择方案一或者方案二。
根据目前搜集到的一些同学平时的使用习惯和需求，可能方案二更适合些，默认分配方案二账户。

### 方案总结

- 使用Docker作为隔离机制，给每个用户分配一个 Docker 容器；
- 为了支持在虚拟机中使用GPU资源，使用nvidia-docker；
- 给每个用户分配一个宿主机上的端口，映射容器的22端口；用户使用 ssh 连接这个端口即可直接进入 Docker 容器；
- 编写容器操作脚本和使用说明，方便用户使用；
- 编写管理员添加用户脚本。

## 搭建过程

### 宿主机配置

我们的服务器是容天AIX4950 GPU工作站，预装有：

- Ubuntu 18.04.5 LTS操作系统
- 显卡驱动450.102.04以及CUDA 10.1
- Docker
- 已有docker用户组，允许非root用户免sudo执行docker命令

在此基础上需要额外进行以下配置：

#### 1、安装nvidia-docker2

添加repositories

```shell
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | \
  sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/ubuntu16.04/amd64/nvidia-docker.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt-get update
```

#### 2、Docker换源，换存储路径

备份daemon.json

```shell
sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
```

修改daemon.json

```shell
sudo vim /etc/docker/daemon.json
```

安装完nvidia-docker后默认应该是这样的配置

```shell
{
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    }
}

```

修改默认运行时为nvidia-docker，添加国内源，修改存储位置为/home/docker，限制日志大小后daemon.json为

```shell
{
    "default-runtime": "nvidia",
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    },
    "registry-mirrors":[
        "https://kfwkfulq.mirror.aliyuncs.com",
        "https://2lqq34jg.mirror.aliyuncs.com",
        "https://pee6w651.mirror.aliyuncs.com",
        "https://registry.docker-cn.com",
        "http://hub-mirror.c.163.com"
    ],
    "data-root": "/home/docker",
    "log-opts": { "max-size": "50m", "max-file": "1"}
}
```

保存退出，并在/home下建立docker文件夹

```shell
cd /home
sudo mkdir docker
```

#### 3、配置容器

##### 3.1 创建容器

首先使用基础镜像手动启容器来观察下效果。

在 daemon.json 中修改了 default-runtime 后，运行容器可以直接使用Docker进行初始化run了。
基础镜像选用CUDA和CUDNN环境的镜像：`nvidia/cuda:10.1-cudnn7-runtime-ubuntu18.04`
更多版本的镜像可以通过 <https://hub.docker.com/r/nvidia/cuda/tags> 查看。

比如，我们可以这样启动一个容器:

```shell
nvidia-docker run -dit -v /home/zhuxx:/home/zhuxx -v /data:/data -p22000:22 --name=zhuxx_container -h=zhuxx-VM cuda-conda-desktop:1.0
```

参数说明如下：

参数 | 含义
---------|----------
 -dit | 容器保持后台运行，返回容器ID
 -p22000:22 | 容器22端口映射到宿主机22000端口
 --name=zhuxx_container | 指定容器名称
 -h=zhuxx-VM | 指定容器的hostname
 -v /home/zhuxx:/home/zhuxx | 将宿主机/home/zhuxx映射到容器/home/zhuxx，一般用于共享目录

注：如果需要控制容器可访问的GPU，可以使用NV_GPU环境变量，如果不加这个参数则容器可以访问全部的GPU。（目前我们没有启用这个参数）

```shell
NV_GPU=0 nvidia-docker run -dit -v /home/zhuxx:/home/zhuxx -v /data:/data -p22000:22 --name=zhuxx_container -h=zhuxx-VM cuda-conda-desktop:1.0
```

进入容器

```shell
docker exec -it zhuxx_container /bin/bash
```

查看GPU是否能正常访问

```shell
nvidia-smi
```

##### 3.2 制作我们自己的镜像

基础镜像启动的容器内的Ubuntu是一个非常精简的系统，缺乏包括`ping` `vi`等一系列常用指令，需要进行额外的配置。

我们借鉴网上做好的一个Dockerfile：[CUDA-Conda-Desktop](https://github.com/hangvane/cuda-conda-desktop)，相比与nvidia-docker提供的base镜像增加了很多常用配置，可以作为实验室其他用户生成自己镜像的base。

```shell
docker pull hangvane/cuda-conda-desktop:ubuntu18.04
```

相关配置如下：

- 配置国内高速apt-get更新源
  
  使用清华源 <https://mirrors.tuna.tsinghua.edu.cn/help/ubuntu/>

```shell
ARG RELEASE_NAME=bionic

# apt sources backup
&& cp /etc/apt/sources.list /etc/apt/sources.list.bak \

# switch apt source to TUNA
&& echo "deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ release-name main restricted universe multiverse\n\
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ release-name-updates main restricted universe multiverse\n\
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ release-name-backports main restricted universe multiverse\n\
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ release-name-security main restricted universe multiverse" >/etc/apt/sources.list \
&& sed -i 's/release-name/'$RELEASE_NAME'/g' /etc/apt/sources.list \

```

- 安装常用库

  –no-install-recommends：避免安装非必须的文件，从而减小镜像的体积；
  -y：yes，在命令行交互提示中，直接输入 yes；
  
```shell
  && apt-get update \
  && apt-get install -y --no-install-recommends \
  apt-utils \
  vim \
  openssh-server \
  net-tools \
  iputils-ping \
  wget \
  curl \
  git \
  iptables \
  bzip2 \
  command-not-found \

```

- 允许root远程连接并设置密码
  
```shell
# enable root access with ssh: replace line starts with '#PermitRootLogin' or 'PermitRootLogin'
&& sed -i '/^#*PermitRootLogin/cPermitRootLogin yes' /etc/ssh/sshd_config \
# set root password
&& echo "root:$ROOT_PASSWD" | chpasswd \
```

- 设置启动脚本

```shell
ENV SSH_PORT 22

# change ssh port & start ssh service when docker container starts
&& echo "#!/bin/bash\n\
sed -i \"s/Port 22/Port \$SSH_PORT/g\" /etc/ssh/sshd_config\n\
service ssh start\n\
/bin/bash" >/home/startup.sh \
&& chmod 777 /home/startup.sh \
```

- 解决中文乱码

docker容器内出现无法输入中文，查看中文字符出现乱码情况，通过在启动脚本中加入更换编码指令进行解决

```shell
# UTF-8 encoding to support chs characters

RUN echo "export LANG=C.UTF-8" >>/etc/profile \
```

##### 3.3 镜像打包

注意要在有 Dockerfile 文件的目录下执行：

```shell
nvidia-docker image build -t cuda-conda-desktop:1.0 .
```

## 后续及待研究工作

1、用户如何保留/制作自己的镜像

  `docker commit` 是比较直接简单的做法，但是不推荐这样做，因为镜像会很大，且对用户来说是黑盒。
  最好是能够编写自己的dockerfile。

2、如何保证容器稳定运行

## 其他概念介绍

### nvidia-docker

nvidia-docker是一个可以使用GPU的docker，nvidia-docker是在docker上做了一层封装，通过nvidia-docker-plugin，然后调用到docker上，其最终实现的还是在docker的启动命令上携带一些必要的参数。因此在安装nvidia-docker之前，还是需要安装docker的。

docker一般都是使用基于CPU的应用，而如果是GPU的话，就需要安装特有的硬件环境，比如需要安装nvidia driver。所以docker容器并不直接支持Nvidia GPU。为了解决这个问题，最早的处理办法是在容器内部，全部重新安装nvidia driver，然后通过设置相应的设备参数来启动container，然而这种办法是很脆弱的。因为宿主机的driver的版本必须完全匹配容器内的driver版本，这样导致docker image无法共享，很可能本地机器的不一致导致每台机器都需要去重复操作，这很大的违背了docker的设计之初。

为了使docker image能很便利的使用Nvidia GPU，从而产生了nvidia-docker，由它来制作nvidia driver的image，这就要求在目标机器上启动container时，确保字符设备以及驱动文件已经被挂载。

nvidia-docker-plugin是一个docker plugin，被用来帮助我们轻松部署container到GPU混合的环境下。类似一个守护进程，发现宿主机驱动文件以及GPU 设备，并且将这些挂载到来自docker守护进程的请求中。以此来支持docker GPU的使用。

nvidia-docker 对原始的 Docker 命令作了封装，只要使用 `nvidia-docker run` 命令运行容器，容器就可以访问主机显卡设备（只要主机安装了显卡驱动）。nvidia-docker 的使用规则和 Docker 是一致的，只需要把命令里的“docker”替换为“nvidia-docker”就可以了。

### 容器端口映射

docker默认是不对外开放端口的。默认情况下，容器可以主动访问到外部网络的连接，但是外部网络无法访问到容器。所以如果在容器内运行网络应用和服务是无法提供给外界使用的，端口映射功能可以实现公网上访问容器内部的网络应用。
详见：[以阿里云服务器为例理解docker端口映射](https://blog.csdn.net/The_Time_Runner/article/details/105031925)

## 参考

- [为实验室建立公用GPU服务器](https://zhuanlan.zhihu.com/p/25710517)
- [使用Docker搭建实验室共享GPU服务器](https://blog.csdn.net/hangvane123/article/details/88639279)
- [用Docker建立一个公用GPU服务器](https://gitchat.csdn.net/columnTopic/5a13c07375462408e0da8e72)

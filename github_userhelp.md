github 是项目托管平台，git是版本管理工具，github是使用git进行版本管理的。

* 本地通过ssh与远程仓库进行通信

××××××××××××××××生成密钥，建立电脑和github账户之间的联系×××××××××××××××××

* 1.首先通过ssh-keygen生成ssh通信的密钥，包括公钥和私玥。文件在.ssh目录下，然后把公钥文件中hostname之前的内容复制到github中去，
在github打开setting, ssh key,中add ssh key,这样就建立啦github和ＰＣ本地通信条件，因为通信的时候需要远程github提供公钥。

* ２.然后安装git，git config --global user.name "chunhui204"
		git config --global user.email "15866613796@163.com"
		建立了git与github之间的联系.
		
* ３. 可以通过git clone git_url，把仓库克隆到本地。


××××××××××××××××关联本地仓库与远程仓库××××××××××××××××××

* １.远程就是github,github上建立仓库就不说了。

* 2.本地通过　git init，把当前目录变成一个仓库，会生成.git文件夹

－－－－－－下面就是关联本地和远程仓库，使用push和pull的时候能够在这两个关联的仓库之间传递文件－－－－－－
git remote add origin git@github.com:chunhui204/tf.git
这里的origin就是指远程仓库，后面是git address or http address
－－－－－－－－－－－－－－－－－－－－－－－－－－－－－－－－－－－－－－－－－－

* 4. 如果本地端修改，可以
git add filename　－－－作修改
git rm filename　－－－做修改
git commit -m "info"　－－备注
git push -u origin master　－－提交
push到远程仓库

* 5. 通过git pull把远程仓库的修改拉到本地。


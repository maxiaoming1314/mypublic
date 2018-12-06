#!/bin/bash
# oracle 11g R2 for linux 安装辅助脚本
# centOS6-7
# version 1.0
# date 2017.10.10
#定义常量(空的需要手动填写)
HOSTIP="192.168.30.11"
HOSTNAME="db_rac01"
oraclepath="/u01/oracle/app"
oracledata="/u01/oracle/oradata"
#oracle use
#循环变量
i=1
#定义显示颜色
#颜色定义 信息(33黄色) 警示(31红色) 过程(36浅蓝)
#判断执行用户是否root、IP
oscheck()
{
#判断是否root
if [ $USER != "root" ];then
echo -e "\n\e[1;31m the user must be root,and now you user is $USER,please su to root. \e[0m"
exit
else
echo -e "\n\e[1;36m check root ... OK! \e[0m"
fi
#判断IP、主机、路径
if [[ ${HOSTIP} == '' || ${HOSTNAME} == '' || ${oraclepath} == '' || ${oracledata} == '' ]];then
  echo -e "\033[31m Constant cannot be empty, Please set ! \033[0m"
  exit
fi
#查看内存大小是否大于1G
echo -e "\n check MEM Size ..."
if [ `cat /proc/meminfo | grep MemTotal | awk '{print $2}'` -lt 1048576 ];then
echo -e "\n\e[1;33m Memory Small \e[0m"
exit 1
else
echo -e "\n\e[1;36m Memory checked ... OK! \e[0m"
fi
#查看tmpfs空间大小,小于1G改成1G
echo -e "\n check tmpfs Size ..."
cp /etc/fstab{,.bak}
while true;do
	if [ `df | awk '/tmpfs/ {print $2}'` -lt 1048576 ];then
	echo -e "\n\e[1;33m tmpfs Smaill \e[0m"
		sed -i '/tmpfs/s/defaults/defaults,size=1G/' /etc/fstab && mount -o remount /dev/shm
		if [ $? != 0 ];then
			i=i+1
				if [ $i -gt 1 ];then
					echo -e "\n\e[1;31m set tmpfs faild. \e[0m"
					exit 3
				fi
		else
			echo -e "\n\e[1;36 tmpfs updated successfully. \e[0m"
			break
		fi
	else
		echo -e "\n\e[1;36m tmpfs checked ... OK \e[0m"
		break
	fi
done
}
#配置主机
confhost()
{
#修改hosts
	if [[ `grep "${HOSTIP} ${HOSTNAME}" /etc/hosts` == "" ]];then
		echo "${HOSTIP} ${HOSTNAME}" >> /etc/hosts
		echo -e "\n\e[1;36m hosts file set ... OK! \e[0m"
fi
#关闭SELINUX
#sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
cp /etc/selinux/config{,.bak} && sed -i '/SELINUX/s/enforcing/disabled/;/SELINUX/s/permissive/disabled/' /etc/selinux/config
setenforce 0
echo -e "\n\e[1;36m setlinux off ... OK! \e[0m"
#开封端口
if [[ `grep "release 6." /etc/redhat-release` != "" ]];then
	if [[ `grep "1521" /etc/sysconfig/iptables` = "" ]];then
	  service iptables stop &&
	  sed -i '/\COMMIT/i -A INPUT -p tcp -m state --state NEW -m tcp --dport 1521 -j ACCEPT' /etc/sysconfig/iptables &&
	  sed -i '/\COMMIT/i -A INPUT -p tcp -m state --state NEW -m tcp --dport 1158 -j ACCEPT' /etc/sysconfig/iptables &&
	  service iptables restart && service iptables save
	fi
		echo -e "\n\e[1;36m centOS6 port 1521,1158 ... OK! \e[0m"
elif [[ `grep "release 7." /etc/redhat-release` != "" ]];then
	firewall-cmd --permanent --zone=public --add-port=1521/tcp &&
	firewall-cmd --permanent --zone=public --add-port=1158/tcp &&
	firewall-cmd --reload
		echo -e "\n\e[1;36m centOS7 port 1521,1158 ... OK! \e[0m"
else
		echo -e "\033[31m port 1521,1158 ... Fail! \033[0m"
exit
fi
#交换内存小于1.5G，则增加2G
if [ `cat /proc/meminfo | grep SwapTotal | awk '{print $2}'` -lt 1572864 ];then
	echo -e "\n set swap please wait ..."	
	dd if=/dev/zero of=swapfree bs=32k count=65515 &&
	mkswap swapfree &&
	swapon swapfree &&
	echo "/tmp/swapfree swap swap defaults 0 0" >> /etc/fstab
	echo -e "\n\e[1;36m swap memory  add ... 2G! \e[0m"
fi
}
#oracle软件包
pagoracle()
{
if [[ `grep "release 6." /etc/redhat-release` != "" ]];then
	for package in binutils compat-libcap1 compat-libstdc++-33 compat-libstdc++-33.i686 elfutils-libelf elfutils-libelf-devel glibc glibc.i686 glibc-common glibc-devel glibc-devel.i686 glibc-headers ksh libaio libaio.i686 libaio-devel libaio-devel.i686 libX11 libX11.i686 libXau libXau.i686 libXi libXi.i686 libXtst libXtst.i686 libgcc libgcc.i686 libstdc++ libstdc++.i686 libstdc++-devel libstdc++-devel.i686 libxcb libxcb.i686 make nfs-utils net-tools smartmontools sysstat unixODBC unixODBC-devel gcc gcc-c++ libXext libXext.i686 zlib-devel zlib-devel.i686 zip unzip wget vim
	do
		rpm -q $package 2> /dev/null
		if [ $? != 0 ];then
		yum -y install $package
		echo -e "\n\e[1;36m $package is already installed ... OK! \e[0m"
		fi
	done
elif [[ `grep "release 7." /etc/redhat-release` != "" ]];then
	for package in binutils compat-libcap1 gcc gcc-c++ glibc.i686 glibc.x86_64 glibc-devel.i686 glibc-devel.x86_64 libaio.i686 libaio.x86_64 libaio-devel.i686 libaio-devel.x86_64 libgcc.i686 libgcc.x86_64 libstdc++.i686 libstdc++.x86_64 libstdc++-devel.i686 libstdc++-devel.x86_64 libXi.i686 libXi.x86_64 libXtst.i686 libXtst.x86_64 make sysstat unixODBC.i686 unixODBC.x86_64 unixODBC-devel.i686  unixODBC-devel.x86_64
	do
		rpm -q $package 2> /dev/null
		if [ $? != 0 ];then
		yum -y install $package
		echo -e "\n\e[1;36m $package is already installed ... OK! \e[0m"
		fi
	done
else
                echo -e "\033[31m package install ... Fail! \033[0m"
exit
fi
#
}
#添加oracle用户，添加oracle用户所属组oinstall及附加组dba
ouseradd()
{
if [[ `grep "oracle" /etc/passwd` = "" ]];then
	groupadd oinstall && groupadd dba &&
	useradd -g oinstall -G dba -d /home/oracle oracle && echo oracle | passwd oracle --stdin
	if [ $? -eq 0 ];then
		echo -e "\n\e[1;36m oracle's password updated successfully --- OK! \e[0m"
	else
		echo -e "\n\e[1;31m oracle's password set faild. --- NO!\e[0m"
	fi
else
echo -e "\033[31m orale user already exist \033[0m"
fi
}
# 设置内核参数
kernelset()
{
cp /etc/sysctl.conf{,.bak} && cat <<EOF >> /etc/sysctl.conf
net.ipv4.ip_local_port_range = 9000 65500
fs.aio-max-nr = 1048576
fs.file-max = 6815744
kernel.shmall = 10523004
kernel.shmmax = 6465333657
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
EOF
if [ $? -eq 0 ];then
echo -e "\n\e[1;36m kernel parameters updated is --- OK! \e[0m"
fi
sysctl -p
}
#设置oracle资源限制
oralimit()
{
cp /etc/security/limits.conf{,.bak} && cat <<EOF >> /etc/security/limits.conf
oracle soft nproc 2047
oracle hard nproc 16384
oracle soft nofile 1024
oracle hard nofile 65536
oracle soft stack 10240
EOF
if [ $? -eq 0 ];then
echo -e "\n\e[1;36m /etc/security/limits.conf updated is ... OK! \e[0m"
fi
}
#设置login文件
setlogin()
{
cp /etc/pam.d/login{,.bak} && cat <<EOF >> /etc/pam.d/login
session required pam_limits.so
EOF
if [ $? -eq 0 ];then
echo -e "\n\e[1;36m /etc/pam.d/login updated is ... OK! \e[0m"
fi
}
#设置profile文件(变量前加\防止变量解析)
setprofile()
{
cp /etc/profile{,.bak} && cat <<EOF >> /etc/profile
if [ \$USER = "oracle" ];then
if [ \$SHELL = "/bin/ksh" ];then
ulimit -p 16384
ulimit -n 65536
else
ulimit -u 16384 -n 65536
fi
fi
EOF
if [ $? -eq 0 ];then
echo -e "\n\e[1;36m /etc/profile updated is ... OK! \e[0m"
fi
}
#创建oracle安装路径及附权(oraclepath=/u01/oracle/app,oracledata=/u01/oracle/oradata)
createpath()
{
if [[ ${oraclepath} != '' ]];then
 ownpath="/"`echo ${oraclepath} | awk -F "/" '{print $2}'`
 invpath=${oraclepath}"/oraInventory"
fi
if [ ! -f "/etc/oraInst.loc" ]; then
  echo "inventory_loc="$oraclepath"/oraInventory""
inst_group=oinstall" > /etc/oraInst.loc && chown oracle:oinstall /etc/oraInst.loc && chmod 764 /etc/oraInst.loc
fi
mkdir -p $oraclepath && chmod -R 755 $oraclepath && 
mkdir -p $oracledata && chmod -R 755 $oracledata && 
mkdir -p $invpath && chmod -R 755 $invpath && chown -R oracle:oinstall $ownpath
if [ $? -eq 0 ];then
 echo -e "\n\e[1;36m create oracle path ... OK! \e[0m"
fi
}
#设置oracle环境变量设置
setbash_profile()
{
cp /home/oracle/.bash_profile{,.bak} && cat <<EOF >> /home/oracle/.bash_profile
umask 022
export ORACLE_BAS=/u01/oracle/app
export ORACLE_HOME=\$ORACLE_BASE/product/11.2.0/dbhome_1
export ORACLE_SID=orcl
export PATH=\$ORACLE_HOME/bin/:\$PATH
LANG=en_US.UTF-8
EOF
if [ $? -eq 0 ];then
echo -e "\n\e[1;36m $BASH_PROFILE updated successfully ... OK! \e[0m"
fi
source /home/oracle/.bash_profile
}

#执行函数
#oscheck
#confhost
#pagoracle
#ouseradd
#kernelset
#oralimit
#setlogin
#setprofile
#createpath
#setbash_profile
echo -e "\n\e[1;35m Oracle install pre-setting finish! && please run oracle installer as user oracle \e[0m"

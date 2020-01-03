#!/usr/bin/bash
#author Ten.J
systemctl stop firewalld &> /dev/null
setenforce 0 &> /dev/null

qjpath=`pwd`

#所需命令
yum -y install net-tools

#ELK-kibana所需用到的所有tar包
java_tar='jdk-8u211-linux-x64.tar.gz'
logstash_tar='logstash-6.5.4.tar.gz'

if [ ! -e $qjpath/$java_tar ]
then
	yum -y install java
else
	echo '开始部署java环境。。。'
	tar xf $qjpath/$java_tar -C /usr/local/
	mv /usr/local/jdk1.8.0_211 /usr/local/java
	echo 'JAVA_HOME=/usr/local/java' >> /etc/profile.d/java.sh
	echo 'PATH=$PATH:$JAVA_HOME/bin' >> /etc/profile.d/java.sh
	echo 'export JAVA_HOME PATH' >> /etc/profile.d/java.sh
	source /etc/profile.d/java.sh
fi	

if [ ! -e $qjpath/$logstash_tar ]
then
	yum -y install wget
	wget https://artifacts.elastic.co/downloads/logstash/$logstash_tar
fi


sleep 1
#配置logstash
echo '开始配置logstash。。。'
tar xf $qjpath/$logstash_tar -C /usr/local/
mv /usr/local/logstash-6.5.4 /usr/local/logstash

#创建目录，我们将所有input、filter、output配置文件全部放到该目录中。
mkdir /usr/local/logstash/conf.d -p

#kafka的所有Ip，逗号间隔
kids='172.31.138.131:9092, 172.31.138.132:9092, 172.31.138.133:9092'

echo '
input {
kafka {
    type => "audit_log"
    codec => "json"
    topics => "nginx"
    decorate_events => true
    bootstrap_servers => "'$kids'"
  }
}
' > /usr/local/logstash/conf.d/input.conf

#es集群ip
es_ips='["172.31.138.134","172.31.138.135","172.31.138.136"]'

echo '
output {
  if [type] == "audit_log" {
      elasticsearch {
      hosts => '${es_ips}'
      index => "logstash-audit_log-%{+YYYY-MM-dd}"
      }
    }
  }
' > /usr/local/logstash/conf.d/output.conf

#启动
echo '正在尝试启动。。。'
nohup /usr/local/logstash/bin/logstash -f /usr/local/logstash/conf.d/  --config.reload.automatic &
sleep 15
netstat -ntlp | grep 9600
if [ $? -ne 0 ]
then
	echo '第一次测试logstash未成功，正在尝试第二次。。。'
	sleep 8
	netstat -ntlp | grep 9600
	if [ $? -ne 0 ]
	then
		echo '第二次测试失败，请检查后重试，这可能是因为机器配置过低启动慢，可以再稍等一会查看端口9600是否启动'
		exit
	else
		echo 'logstash已配置完成并启动'
	fi	
fi





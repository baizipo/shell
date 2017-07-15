#!/bin/bash

#install base docker environment

OPT=$1
dir=`pwd`
usage()
{

 warn_echo "Usage: `basename $0` [all|install|boot|config|ntp_postfix|destroy]"
}

warn_echo(){
  echo -e "\e[31m$1 \033[0m" 
}

okey_echo(){
  echo -e "\e[92m$1 \033[0m"
}

if [ $# -ne 1 ] ; then
    usage
    exit 1
fi      


docker_config='DOCKER_OPTS="$DOCKER_OPTS --registry-mirror=http://f2d6cb40.m.daocloud.io --live-restore"'
deb_rep='deb http://127.0.0.1/suninfo/local_mirrors/ubuntu/14.04 trusty main restricted'
sys_conf='vm.max_map_count = 262144'

base() { 

if [ "$dir" != "/opt/install_Unistor" ];
   then
       warn_echo "Please cp install_Unistor to /opt " && exit 
fi

#cp -r $dir/suninfo/  /home/ubuntu
cd /home/ubuntu
nohup /usr/bin/python -m SimpleHTTPServer 80 >> /dev/null 2>&1 &

apt-key add /home/ubuntu/suninfo/local_mirrors/ubuntu/public.key > /dev/null 2>&1

if [ `grep -c "${deb_rep}" /etc/apt/sources.list` -eq 0 ];
   then 
       sed -i '1i\'"${deb_rep}"'' /etc/apt/sources.list
       apt-get update >> /dev/null 2>&1  && apt-get -y install apt-transport-https ca-certificates linux-image-extra-$(uname -r) linux-image-extra-virtual docker-engine >> /dev/null 2>&1
   else
       apt-get update >> /dev/null 2>&1  && apt-get -y install apt-transport-https ca-certificates linux-image-extra-$(uname -r) linux-image-extra-virtual docker-engine >> /dev/null 2>&1
fi

if [ `dpkg -l | grep docker-engine | wc -l` -eq 1 ];then 
    `ps -ef | grep SimpleHTTPServer | grep -v grep | awk -F ' ' '{print $2}'| xargs -i kill -9 {}` 2>/dev/null
    if [ `grep -c "${docker_config}" /etc/default/docker` -eq 0 ];
       then
           sed -i '$a\'"${docker_config}"'' /etc/default/docker && service docker restart >> /dev/null
       else
           service docker restart >> /dev/null
    fi
else
    warn_echo "Docker-engine Install Error" && exit 5
fi
}

#config dockerimages;start container

docker_create() {

if [ `grep -c "${sys_conf}" /etc/sysctl.conf |wc -l` -eq 0 ];
    then
        sed -i '1i\'"${sys_conf}"'' /etc/sysctl.conf && sysctl -p && sysctl -a >> /dev/null 2>&1
    else
        sysctl -p >> /dev/null 2>&1  && sysctl -a >> /dev/null 2>&1
fi
cp $dir/pkgs/docker-compose-Linux-x86_64  /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose

for i in $(ls $dir/dockerimages);do /usr/bin/docker load < $dir/dockerimages/$i >> /dev/null 2>&1;done

okey_echo "Install complete,Please config /opt/install_Unistor/franky/docker-compose.yml,Then execute ./install.sh boot"
}

boot_container(){
cd $dir/franky && /usr/local/bin/docker-compose up -d >> /dev/null 2>&1

if [ `/usr/bin/docker ps -a -q|wc -l` -ge 10 ];
   then 
      okey_echo "Boot_Containter_complete,next config container..."
else
      warn_echo "Containter boot error,please check it..."
fi
sed -i 's#deb http://127.0.0.1/suninfo#deb http://127.0.0.1:8029#g' /etc/apt/sources.list
}

docker_destroy() {
containers_id=`/usr/bin/docker ps -a -q`
images_id=`/usr/bin/docker images -q`
for con_id in ${containers_id};do /usr/bin/docker stop ${con_id} && /usr/bin/docker rm ${con_id};done >>/dev/null
for image_id in ${images_id};do /usr/bin/docker rmi ${image_id};done >> /dev/null
sed -i '1d' /etc/apt/sources.list
okey_echo "Docker destroy compute"
}

config() {
/usr/bin/docker exec influxdb influx -execute 'create database physics_monitor' >> /dev/null 2>&1
/usr/bin/docker exec kapacitor /bin/bash -execute '/opt/tick_scripts/create_task.sh'  >> /dev/null 2>&1
okey_echo "Please login suninfo/portal config /etc/dashboard/setting && restart it"

}

ntp_postfix(){
apt-get install ntp mailutils >> /dev/null 2>&1
cp /usr/share/postfix/main.cf.debian /etc/postfix/main.cf
sed -i '1i\smtpd_use_tls=no' /etc/postfix/main.cf
sed -i '1i\mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128 192.168.206.0/24' /etc/postfix/main.cf

service postfix restart >> /dev/null 2>&1

echo > /etc/ntp.conf
cat>>/etc/ntp.conf<<EOF
server 127.127.1.0
fudge 127.127.1.0 stratum 10
driftfile /etc/ntp/drift
restrict 127.0.0.1
EOF

service ntp restart >> /dev/null 2>&1

okey_echo "ntp & postfix complete config"
}

case $OPT in
     all|All) okey_echo "Start install and config..."
     base
     docker_create
     boot_container
     config
     ntp_postfix
     ;;
     install|Install) okey_echo "Starting install docker-engine..."
     base
     docker_create
     ;;
     boot|Boot) okey_echo "Boot Containter..."
     boot_container
     ;;
     config|Config) okey_echo "Start Configing..."
     config
     ;;
     ntp_postfix|Ntp) okey_echo "Install ntp_postfix"
     ntp_postfix
     ;;
     destroy|Destroy) okey_echo "Destroying docker..."
     docker_destroy
     ;;
     *)usage
     ;;
esac    

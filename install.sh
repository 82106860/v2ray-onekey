#!/bin/bash

#====================================================
#	System Request:Debian 7+/Ubuntu 14.04+/Centos 6+
#	Author:	wulabing,breakwa2333
#	Dscription: V2ray ws+tls onekey 
#	Version: 1.0.0
#	Blog: https://www.wulabing.com
#	Official document: www.v2ray.com
#====================================================

#fonts color
Green="\033[32m" 
Red="\033[31m" 
Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"

#notification information
Info="${Green}[��Ϣ]${Font}"
OK="${Green}[OK]${Font}"
Error="${Red}[����]${Font}"

v2ray_conf_dir="/etc/v2ray"
nginx_conf_dir="/etc/nginx/conf.d"
v2ray_conf="${v2ray_conf_dir}/config.json"
nginx_conf="${nginx_conf_dir}/v2ray.conf"

#����αװ·��
camouflage=`cat /dev/urandom | head -n 10 | md5sum | head -c 8`

source /etc/os-release

#��VERSION����ȡ���а�ϵͳ��Ӣ�����ƣ�Ϊ����debian/ubuntu��������Ӧ��Nginx aptԴ
VERSION=`echo ${VERSION} | awk -F "[()]" '{print $2}'`

check_system(){
    
    if [[ "${ID}" == "centos" && ${VERSION_ID} -ge 7 ]];then
        echo -e "${OK} ${GreenBG} ��ǰϵͳΪ Centos ${VERSION_ID} ${VERSION} ${Font} "
        INS="yum"
        echo -e "${OK} ${GreenBG} SElinux �����У������ĵȴ�����Ҫ������������${Font} "
        setsebool -P httpd_can_network_connect 1
        echo -e "${OK} ${GreenBG} SElinux ������� ${Font} "
        ## Centos Ҳ����ͨ����� epel �ֿ�����װ��Ŀǰ�����Ķ�
        cat>/etc/yum.repos.d/nginx.repo<<EOF
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/mainline/centos/7/\$basearch/
gpgcheck=0
enabled=1
EOF
        echo -e "${OK} ${GreenBG} Nginx Դ ��װ��� ${Font}" 
    elif [[ "${ID}" == "debian" && ${VERSION_ID} -ge 8 ]];then
        echo -e "${OK} ${GreenBG} ��ǰϵͳΪ Debian ${VERSION_ID} ${VERSION} ${Font} "
        INS="apt"
        ## ��� Nginx aptԴ
        if [ ! -f nginx_signing.key ];then
        echo "deb http://nginx.org/packages/mainline/debian/ ${VERSION} nginx" >> /etc/apt/sources.list
        echo "deb-src http://nginx.org/packages/mainline/debian/ ${VERSION} nginx" >> /etc/apt/sources.list
        wget -nc https://nginx.org/keys/nginx_signing.key
        apt-key add nginx_signing.key
        fi
    elif [[ "${ID}" == "ubuntu" && `echo "${VERSION_ID}" | cut -d '.' -f1` -ge 16 ]];then
        echo -e "${OK} ${GreenBG} ��ǰϵͳΪ Ubuntu ${VERSION_ID} ${VERSION_CODENAME} ${Font} "
        INS="apt"
        ## ��� Nginx aptԴ
        if [ ! -f nginx_signing.key ];then
        echo "deb http://nginx.org/packages/mainline/ubuntu/ ${VERSION_CODENAME} nginx" >> /etc/apt/sources.list
        echo "deb-src http://nginx.org/packages/mainline/ubuntu/ ${VERSION_CODENAME} nginx" >> /etc/apt/sources.list
        wget -nc https://nginx.org/keys/nginx_signing.key
        apt-key add nginx_signing.key
        fi
    else
        echo -e "${Error} ${RedBG} ��ǰϵͳΪ ${ID} ${VERSION_ID} ����֧�ֵ�ϵͳ�б��ڣ���װ�ж� ${Font} "
        exit 1
    fi

}
is_root(){
    if [ `id -u` == 0 ]
        then echo -e "${OK} ${GreenBG} ��ǰ�û���root�û������밲װ���� ${Font} "
        sleep 3
    else
        echo -e "${Error} ${RedBG} ��ǰ�û�����root�û������л���root�û�������ִ�нű� ${Font}" 
        exit 1
    fi
}
judge(){
    if [[ $? -eq 0 ]];then
        echo -e "${OK} ${GreenBG} $1 ��� ${Font}"
        sleep 1
    else
        echo -e "${Error} ${RedBG} $1 ʧ��${Font}"
        exit 1
    fi
}
ntpdate_install(){
    if [[ "${ID}" == "centos" ]];then
        ${INS} install ntpdate -y
    else
        ${INS} update
        ${INS} install ntpdate -y
    fi
    judge "��װ NTPdate ʱ��ͬ������ "
}
time_modify(){

    ntpdate_install

    systemctl stop ntp &>/dev/null

    echo -e "${Info} ${GreenBG} ���ڽ���ʱ��ͬ�� ${Font}"
    ntpdate time.nist.gov

    if [[ $? -eq 0 ]];then 
        echo -e "${OK} ${GreenBG} ʱ��ͬ���ɹ� ${Font}"
        echo -e "${OK} ${GreenBG} ��ǰϵͳʱ�� `date -R`����ע��ʱ����ʱ�任�㣬�����ʱ�����ӦΪ���������ڣ�${Font}"
        sleep 1
    else
        echo -e "${Error} ${RedBG} ʱ��ͬ��ʧ�ܣ�����ntpdate�����Ƿ��������� ${Font}"
    fi 
}
dependency_install(){
    ${INS} install wget git lsof -y

    if [[ "${ID}" == "centos" ]];then
       ${INS} -y install crontabs
    else
        ${INS} install cron
    fi
    judge "��װ crontab"

    # �°��IP�ж�����Ҫʹ��net-tools
    # ${INS} install net-tools -y
    # judge "��װ net-tools"

    ${INS} install bc -y
    judge "��װ bc"

    ${INS} install unzip -y
    judge "��װ unzip"
}
port_alterid_set(){
    stty erase '^H' && read -p "���������Ӷ˿ڣ�default:443��:" port
    [[ -z ${port} ]] && port="443"
    stty erase '^H' && read -p "������alterID��default:64��:" alterID
    [[ -z ${alterID} ]] && alterID="64"
}
modify_port_UUID(){
    let PORT=$RANDOM+10000
    UUID=$(cat /proc/sys/kernel/random/uuid)
    sed -i "/\"port\"/c  \    \"port\":${PORT}," ${v2ray_conf}
    sed -i "/\"id\"/c \\\t  \"id\":\"${UUID}\"," ${v2ray_conf}
    sed -i "/\"alterId\"/c \\\t  \"alterId\":${alterID}" ${v2ray_conf}
    sed -i "/\"path\"/c \\\t  \"path\":\"\/${camouflage}\/\"" ${v2ray_conf}
}
modify_nginx(){
    ## sed ���ֵط� ��Ӧ����������
    if [[ -f /etc/nginx/nginx.conf.bak ]];then
        cp /etc/nginx/nginx.conf.bak /etc/nginx/nginx.conf
    fi
    sed -i "1,/listen/{s/listen 443 ssl;/listen ${port} ssl;/}" ${v2ray_conf}
    sed -i "/server_name/c \\\tserver_name ${domain};" ${nginx_conf}
    sed -i "/location/c \\\tlocation \/${camouflage}\/" ${nginx_conf}
    sed -i "/proxy_pass/c \\\tproxy_pass http://127.0.0.1:${PORT};" ${nginx_conf}
    sed -i "/return/c \\\treturn 301 https://${domain}\$request_uri;" ${nginx_conf}
    sed -i "27i \\\tproxy_intercept_errors on;"  /etc/nginx/nginx.conf
}
web_camouflage(){
    ##��ע�� �����LNMP�ű���Ĭ��·����ͻ��ǧ��Ҫ�ڰ�װ��LNMP�Ļ�����ʹ�ñ��ű����������Ը�
    rm -rf /home/webroot && mkdir -p /home/webroot && mkdir -p /home/webtemp
    pathing=$[$[$RANDOM % 6] + 1] 
    wget https://github.com/breakwa2333/v2ray-onekey/blob/master/template/$pathing.zip?raw=true -O /home/webtemp/$pathing.zip
    unzip -d /home/webroot /home/webtemp/$pathing.zip
    judge "web վ��αװ"   
}
v2ray_install(){
    if [[ -d /root/v2ray ]];then
        rm -rf /root/v2ray
    fi

    mkdir -p /root/v2ray && cd /root/v2ray
    wget --no-check-certificate https://install.direct/go.sh

    ## wget http://install.direct/go.sh
    
    if [[ -f go.sh ]];then
        bash go.sh --force --version v4.18.0
        judge "��װ V2ray"
    else
        echo -e "${Error} ${RedBG} V2ray ��װ�ļ�����ʧ�ܣ��������ص�ַ�Ƿ���� ${Font}"
        exit 4
    fi
}
nginx_install(){
    ${INS} install nginx -y
    if [[ -d /etc/nginx ]];then
        echo -e "${OK} ${GreenBG} nginx ��װ��� ${Font}"
        sleep 2
    else
        echo -e "${Error} ${RedBG} nginx ��װʧ�� ${Font}"
        exit 5
    fi
    if [[ ! -f /etc/nginx/nginx.conf.bak ]];then
        cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
        echo -e "${OK} ${GreenBG} nginx ��ʼ���ñ������ ${Font}"
        sleep 1
    fi
}
ssl_install(){
    if [[ "${ID}" == "centos" ]];then
        ${INS} install socat nc -y        
    else
        ${INS} install socat netcat -y
    fi
    judge "��װ SSL ֤�����ɽű�����"

    curl  https://get.acme.sh | sh
    judge "��װ SSL ֤�����ɽű�"

}
domain_check(){
    stty erase '^H' && read -p "���������������Ϣ(eg:www.v2ray.com):" domain
    domain_ip=`ping ${domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
    echo -e "${OK} ${GreenBG} ���ڻ�ȡ ����ip ��Ϣ�������ĵȴ� ${Font}"
    local_ip=`curl -4 ip.sb`
    echo -e "����dns����IP��${domain_ip}"
    echo -e "����IP: ${local_ip}"
    sleep 2
    if [[ $(echo ${local_ip}|tr '.' '+'|bc) -eq $(echo ${domain_ip}|tr '.' '+'|bc) ]];then
        echo -e "${OK} ${GreenBG} ����dns����IP  �� ����IP ƥ�� ${Font}"
        sleep 2
    else
        echo -e "${Error} ${RedBG} ����dns����IP �� ����IP ��ƥ�� �Ƿ������װ����y/n��${Font}" && read install
        case $install in
        [yY][eE][sS]|[yY])
            echo -e "${GreenBG} ������װ ${Font}" 
            sleep 2
            ;;
        *)
            echo -e "${RedBG} ��װ��ֹ ${Font}" 
            exit 2
            ;;
        esac
    fi
}

port_exist_check(){
    if [[ 0 -eq `lsof -i:"$1" | wc -l` ]];then
        echo -e "${OK} ${GreenBG} $1 �˿�δ��ռ�� ${Font}"
        sleep 1
    else
        echo -e "${Error} ${RedBG} ��⵽ $1 �˿ڱ�ռ�ã�����Ϊ $1 �˿�ռ����Ϣ ${Font}"
        lsof -i:"$1"
        echo -e "${OK} ${GreenBG} 5s �󽫳����Զ� kill ռ�ý��� ${Font}"
        sleep 5
        lsof -i:"$1" | awk '{print $2}'| grep -v "PID" | xargs kill -9
        echo -e "${OK} ${GreenBG} kill ��� ${Font}"
        sleep 1
    fi
}

acme(){
    ~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-384 --force
    if [[ $? -eq 0 ]];then
        echo -e "${OK} ${GreenBG} SSL ֤�����ɳɹ� ${Font}"
        sleep 2
        ~/.acme.sh/acme.sh --installcert -d ${domain} --fullchainpath /etc/v2ray/v2ray.crt --keypath /etc/v2ray/v2ray.key --ecc
        if [[ $? -eq 0 ]];then
        echo -e "${OK} ${GreenBG} ֤�����óɹ� ${Font}"
        sleep 2
        fi
    else
        echo -e "${Error} ${RedBG} SSL ֤������ʧ�� ${Font}"
        exit 1
    fi
}
v2ray_conf_add(){
    cd /etc/v2ray
    wget https://raw.githubusercontent.com/breakwa2333/v2ray-onekey/master/tls/config.json -O config.json
modify_port_UUID
judge "V2ray �����޸�"
}
nginx_conf_add(){
    touch ${nginx_conf_dir}/v2ray.conf
    cat>${nginx_conf_dir}/v2ray.conf<<EOF
    server {
        listen 443 ssl;
        ssl on;
        ssl_certificate       /etc/v2ray/v2ray.crt;
        ssl_certificate_key   /etc/v2ray/v2ray.key;
        ssl_protocols         TLSv1.2;
        ssl_ciphers           AESGCM;
        server_name           serveraddr.com;
        index index.html index.htm;
        root  /home/webroot;
        error_page 400 = /400.html;
        location /ray/ 
        {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        }
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
}
    server {
        listen 80;
        server_name serveraddr.com;
        return 301 https://use.shadowsocksr.win\$request_uri;
    }
EOF

modify_nginx
judge "Nginx �����޸�"

}

start_process_systemd(){
    ### nginx�����ڰ�װ��ɺ���Զ���������Ҫͨ��restart��reload���¼�������
    systemctl start nginx 
    judge "Nginx ����"


    systemctl start v2ray
    judge "V2ray ����"
}

acme_cron_update(){
    if [[ "${ID}" == "centos" ]];then
        sed -i "/acme.sh/c 0 0 * * 0 systemctl stop nginx && \"/root/.acme.sh\"/acme.sh --cron --home \"/root/.acme.sh\" \
        > /dev/null && systemctl start nginx " /var/spool/cron/root
    else
        sed -i "/acme.sh/c 0 0 * * 0 systemctl stop nginx && \"/root/.acme.sh\"/acme.sh --cron --home \"/root/.acme.sh\" \
        > /dev/null && systemctl start nginx " /var/spool/cron/crontabs/root
    fi
    judge "cron �ƻ��������"
}
show_information(){
    clear

    echo -e "${OK} ${Green} V2ray+ws+tls ��װ�ɹ� "
    echo -e "${Red} V2ray ������Ϣ ${Font}"
    echo -e "${Red} ��ַ��address��:${Font} ${domain} "
    echo -e "${Red} �˿ڣ�port����${Font} ${port} "
    echo -e "${Red} �û�id��UUID����${Font} ${UUID}"
    echo -e "${Red} ����id��alterId����${Font} ${alterID}"
    echo -e "${Red} ���ܷ�ʽ��security����${Font} ����Ӧ "
    echo -e "${Red} ����Э�飨network����${Font} ws "
    echo -e "${Red} αװ���ͣ�type����${Font} none "
    echo -e "${Red} ·������Ҫ����/����${Font} /${camouflage}/ "
    echo -e "${Red} �ײ㴫�䰲ȫ��${Font} tls "

    

}

main(){
    is_root
    check_system
    time_modify
    dependency_install
    domain_check
    port_alterid_set
    port_exist_check 80
    port_exist_check ${port}
    v2ray_install
    nginx_install
    v2ray_conf_add
    nginx_conf_add
    web_camouflage

    #�ı�֤�鰲װλ�ã���ֹ�˿ڳ�ͻ�ر����Ӧ��
    systemctl stop nginx
    systemctl stop v2ray
    
    #��֤�����ɷ�����󣬾��������γ��Խű��Ӷ���ɵĶ��֤������
    ssl_install
    acme
    
    show_information
    start_process_systemd
    acme_cron_update
}

main

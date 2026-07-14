#!/bin/bash
# onekey ArgoSB
linux_os=("Debian" "Ubuntu" "CentOS" "Fedora" "Alpine")
linux_update=("apt update" "apt update" "yum -y update" "yum -y update" "apk update")
linux_install=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "apk add -f")
sbcore=1.13.14 #限制sing-box版本
n=0

for i in $(echo ${linux_os[@]})
do
	if [ "$i" == "$(grep -i PRETTY_NAME /etc/os-release | cut -d \" -f2 | awk '{print $1}')" ]
	then
		break
	else
		n=$[$n+1]
	fi
done

if [ $n == 5 ]
then
	echo "当前系统 $(grep -i PRETTY_NAME /etc/os-release | cut -d \" -f2) 没有适配"
	echo "默认使用 APT 包管理器"
	n=0
fi

if [ -z "$(type -P unzip)" ]
then
	${linux_update[$n]}
	${linux_install[$n]} unzip
fi

if [ -z "$(type -P curl)" ]
then
	${linux_update[$n]}
	${linux_install[$n]} curl
fi

if [ "$(grep -i PRETTY_NAME /etc/os-release | cut -d \" -f2 | awk '{print $1}')" != "Alpine" ]
then
	if [ -z "$(type -P systemctl)" ]
	then
		${linux_update[$n]}
		${linux_install[$n]} systemctl
	fi
fi

function installtunnel(){
#创建主目录
mkdir -p /opt/suoha/ >/dev/null 2>&1
rm -rf sing-box cloudflared-linux sing-box.tar.gz

case "$(uname -m)" in
	x86_64 | x64 | amd64 )
	curl -L https://github.com/SagerNet/sing-box/releases/download/v$sbcore/sing-box-$sbcore-linux-amd64.tar.gz -o sing-box.tar.gz
	curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared-linux
	tar -xzvf sing-box.tar.gz
	mv sing-box-$sbcore-linux-amd64 sing-box
	;;
	i386 | i686 )
	curl -L https://github.com/SagerNet/sing-box/releases/download/v$sbcore/sing-box-$sbcore-linux-386.tar.gz -o sing-box.tar.gz
	curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-386 -o cloudflared-linux
	tar -xzvf sing-box.tar.gz
	mv sing-box-$sbcore-linux-386 sing-box
	;;
	armv8 | arm64 | aarch64 )
	echo "arm64"
	curl -L https://github.com/SagerNet/sing-box/releases/download/v$sbcore/sing-box-$sbcore-linux-arm64.tar.gz -o sing-box.tar.gz
	curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -o cloudflared-linux
	tar -xzvf sing-box.tar.gz
	mv sing-box-$sbcore-linux-arm64 sing-box
	;;
	armv71 )
	curl -L https://github.com/SagerNet/sing-box/releases/download/v$sbcore/sing-box-$sbcore-linux-armv7.tar.gz -o sing-box.tar.gz
	curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm -o cloudflared-linux
	tar -xzvf sing-box.tar.gz
	mv sing-box-$sbcore-linux-armv7 sing-box
	;;
	* )
	echo "当前架构 $(uname -m) 没有适配"
	exit 1
	;;
esac

chmod +x cloudflared-linux sing-box/sing-box
mv cloudflared-linux /opt/suoha/
mv sing-box/* /opt/suoha/
rm -rf sing-box sing-box.tar.gz
uuid=$(cat /proc/sys/kernel/random/uuid)
urlpath=$(echo $uuid | awk -F- '{print $1}')
port=$[$RANDOM+10000]

if [ "$daili" == "0" ]
then
cat>/opt/suoha/config.json<<EOF
{
	"log": {
		"disabled": false,
		"level": "info",
		"timestamp": true
	},
	"inbounds": [
		{
		    "type": "vmess",
        	"tag": "vmess-sb",
			"listen_port": $port,
			"listen": "::",
			"users": [
				{
					"uuid": "$uuid",
					"alterId": 0
				}
			],
			"transport": {
				"type": "ws",
				"path": "$urlpath",
				"max_early_data":2048,
				"early_data_header_name": "Sec-WebSocket-Protocol"    
			},
			"tls":{
				"enabled": false
			}
		}
	],
	"outbounds": [
		{
			"type":"direct",
			"tag":"direct"
		}
	]
}
EOF
fi

if [ "$daili" == "1" ]
then
cat>/opt/suoha/config.json<<EOF
{
	"log": {
		"disabled": false,
		"level": "info",
		"timestamp": true
	},
	"inbounds": [
		{
		    "type": "vmess",
        	"tag": "vmess-sb",
			"listen_port": $port,
			"listen": "::",
			"users": [
				{
					"uuid": "$uuid",
					"alterId": 0
				}
			],
			"transport": {
				"type": "ws",
				"path": "$urlpath",
				"max_early_data":2048,
				"early_data_header_name": "Sec-WebSocket-Protocol"    
			},
			"tls":{
				"enabled": false
			}
		}
	],
	"outbounds": [
		{
			"type":"direct",
			"tag":"direct"
		},
		{
			"type": "http",
			"tag": "vpn",
			"server": "127.0.0.1",
			"server_port": 7928
		}
	],
	"route": {
		"rules": [
			{
				"action": "sniff"
			},
			{
				"rule_set": "my-rule-set",
				"outbound": "vpn"
			}
		],
		"rule_set": [
		    {
				"type": "remote",
				"tag": "my-rule-set",
				"format": "binary",
				"url": "https://raw.githubusercontent.com/yuehen7/ArgoSB/main/my-rule-set.json"
			}
		]
	}
}
EOF
fi

clear
echo "复制下面的链接,用浏览器打开并授权需要绑定的域名"
echo "在网页中授权完毕后会继续进行下一步设置"
/opt/suoha/cloudflared-linux --edge-ip-version $ips --protocol http2 tunnel login
clear

/opt/suoha/cloudflared-linux --edge-ip-version $ips --protocol http2 tunnel list >argo.log 2>&1
echo -e "ARGO TUNNEL当前已经绑定的服务如下\n"
sed 1,2d argo.log | awk '{print $2}'
echo -e '\n'
echo "自定义一个完整二级域名,例如 xxx.example.com"
echo "必须是网页里面绑定授权的域名才生效,不能乱输入"
read -p "输入绑定域名的完整二级域名: " domain

if [ -z "$domain" ]
then
	echo "没有设置域名"
	rm -rf argo.log
	exit 1
elif [ $(echo $domain | grep "\." | wc -l) == 0 ]
then
	echo "域名格式不正确"
	rm -rf argo.log
	exit 1
fi

name=$(echo $domain | awk -F\. '{print $1}')
if [ $(sed 1,2d argo.log | awk '{print $2}' | grep -w $name | wc -l) == 0 ]
then
	echo "创建TUNNEL $name"
	/opt/suoha/cloudflared-linux --edge-ip-version $ips --protocol http2 tunnel create $name >argo.log 2>&1
	echo "TUNNEL $name 创建成功"
else
	echo "TUNNEL $name 已经存在"
	if [ ! -f "/root/.cloudflared/$(sed 1,2d argo.log | awk '{print $1" "$2}' | grep -w $name | awk '{print $1}').json" ]
	then
		echo "/root/.cloudflared/$(sed 1,2d argo.log | awk '{print $1" "$2}' | grep -w $name | awk '{print $1}').json 文件不存在"
		echo "清理TUNNEL $name"
		/opt/suoha/cloudflared-linux --edge-ip-version $ips --protocol http2 tunnel cleanup $name >argo.log 2>&1
		echo "删除TUNNEL $name"
		/opt/suoha/cloudflared-linux --edge-ip-version $ips --protocol http2 tunnel delete $name >argo.log 2>&1
		echo "重建TUNNEL $name"
		/opt/suoha/cloudflared-linux --edge-ip-version $ips --protocol http2 tunnel create $name >argo.log 2>&1
	else
		echo "清理TUNNEL $name"
		/opt/suoha/cloudflared-linux --edge-ip-version $ips --protocol http2 tunnel cleanup $name >argo.log 2>&1
	fi
fi

echo "绑定 TUNNEL $name 到域名 $domain"
/opt/suoha/cloudflared-linux --edge-ip-version $ips --protocol http2 tunnel route dns --overwrite-dns $name $domain >argo.log 2>&1
echo "$domain 绑定成功"
tunneluuid=$(grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' argo.log | head -n1)

# 保底防错：若通过日志没拿到uuid，尝试去配置目录检索最新的json
if [ -z "$tunneluuid" ]; then
	tunneluuid=$(ls -lt /root/.cloudflared/*.json 2>/dev/null | head -n1 | awk '{print $9}' | xargs basename -s .json)
fi

echo -e "vmess链接已经生成, saas.sin.fan 可替换为CF优选IP\n" >/opt/suoha/sb.txt
echo 'vmess://'$(echo '{"add":"saas.sin.fan","aid":"0","host":"'$domain'","id":"'$uuid'","net":"ws","path":"'/$urlpath?ed=2048'","port":"443","ps":"'$(echo $isp | sed -e 's/_/ /g')'","tls":"tls","sni":"'$domain'","alpn":"http\/1.1","type":"none","v":"2"}' | base64 -w 0) >>/opt/suoha/sb.txt
echo -e "\n端口 443 可改为 2053 2083 2087 2096 8443\n" >>/opt/suoha/sb.txt
echo 'vmess://'$(echo '{"add":"saas.sin.fan","aid":"0","host":"'$domain'","id":"'$uuid'","net":"ws","path":"'/$urlpath?ed=2048'","port":"80","ps":"'$(echo $isp | sed -e 's/_/ /g')'","tls":"","type":"none","v":"2"}' | base64 -w 0) >>/opt/suoha/sb.txt
echo -e "\n端口 80 可改为 8080 8880 2052 2082 2086 2095\n" >>/opt/suoha/sb.txt
echo "注意:如果 80 8080 8880 2052 2082 2086 2095 端口无法正常使用" >>/opt/suoha/sb.txt
echo "请前往 https://dash.cloudflare.com/" >>/opt/suoha/sb.txt
echo "检查管理面板 SSL/TLS - 边缘证书 - 始终使用HTTPS 是否处于关闭状态" >>/opt/suoha/sb.txt

rm -rf argo.log

cat>/opt/suoha/config.yaml<<EOF
tunnel: $tunneluuid
credentials-file: /root/.cloudflared/$tunneluuid.json

ingress:
  - hostname: $domain
    service: http://localhost:$port
  - service: http_status:404
EOF

if [ "$(grep -i PRETTY_NAME /etc/os-release | cut -d \" -f2 | awk '{print $1}')" == "Alpine" ]
then
cat>/etc/local.d/cloudflared.start<<EOF
/opt/suoha/cloudflared-linux --edge-ip-version $ips --protocol http2 tunnel --config /opt/suoha/config.yaml run $name &
EOF
cat>/etc/local.d/sing-box.start<<EOF
/opt/suoha/sing-box run -c /opt/suoha/config.json &
EOF
chmod +x /etc/local.d/cloudflared.start /etc/local.d/sing-box.start
rc-update add local
/etc/local.d/cloudflared.start >/dev/null 2>&1
/etc/local.d/sing-box.start >/dev/null 2>&1
else
#创建服务
cat>/lib/systemd/system/cloudflared.service<<EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
TimeoutStartSec=0
Type=simple
ExecStart=/opt/suoha/cloudflared-linux --edge-ip-version $ips --protocol http2 tunnel --config /opt/suoha/config.yaml run $name
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
cat>/lib/systemd/system/sing-box.service<<EOF
[Unit]
Description=sing-box
After=network.target

[Service]
TimeoutStartSec=0
Type=simple
ExecStart=/opt/suoha/sing-box run -c /opt/suoha/config.json
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
systemctl enable cloudflared.service >/dev/null 2>&1
systemctl enable sing-box.service >/dev/null 2>&1
systemctl --system daemon-reload
systemctl start cloudflared.service
systemctl start sing-box.service
fi

if [ "$(grep -i PRETTY_NAME /etc/os-release | cut -d \" -f2 | awk '{print $1}')" == "Alpine" ]
then
#创建命令链接 (Alpine版子菜单管理脚本)
cat>/opt/suoha/suoha.sh<<EOF
#!/bin/bash
while true
do
if ! pgrep -f cloudflared-linux > /dev/null
then
	argostatus="stop"
else
	argostatus="running"
fi
if ! pgrep -f sing-box > /dev/null
then
	xraystatus="stop"
else
	xraystatus="running"
fi
echo "argo \$argostatus"
echo "sing-box \$xraystatus"
echo "1.管理TUNNEL"
echo "2.启动服务"
echo "3.停止服务"
echo "4.重启服务"
echo "5.卸载服务"
echo "6.查看当前sing-box链接"
echo "0.退出"
read -p "请选择菜单(默认0): " menu
if [ -z "\$menu" ]
then
	menu=0
fi
if [ \$menu == 1 ]
then
	clear
	while true
	do
		echo "ARGO TUNNEL当前已经绑定的服务如下"
		/opt/suoha/cloudflared-linux tunnel list
		echo "1.删除TUNNEL"
		echo "0.退出"
		read -p "请选择菜单(默认0): " tunneladmin
		if [ -z "\$tunneladmin" ]
		then
			tunneladmin=0
		fi
		if [ \$tunneladmin == 1 ]
		then
			read -p "请输入要删除的TUNNEL NAME: " tunnelname
			echo "断开TUNNEL \$tunnelname"
			/opt/suoha/cloudflared-linux tunnel cleanup \$tunnelname
			echo "删除TUNNEL \$tunnelname"
			/opt/suoha/cloudflared-linux tunnel delete \$tunnelname
		else
			break
		fi
	done
elif [ \$menu == 2 ]
then
	pkill -f sing-box >/dev/null 2>&1
	pkill -f cloudflared-linux >/dev/null 2>&1
	/etc/local.d/cloudflared.start >/dev/null 2>&1
	/etc/local.d/sing-box.start >/dev/null 2>&1
	clear
	sleep 1
elif [ \$menu == 3 ]
then
	pkill -f sing-box >/dev/null 2>&1
	pkill -f cloudflared-linux >/dev/null 2>&1
	clear
	sleep 2
elif [ \$menu == 4 ]
then
	pkill -f sing-box >/dev/null 2>&1
	pkill -f cloudflared-linux >/dev/null 2>&1
	/etc/local.d/cloudflared.start >/dev/null 2>&1
	/etc/local.d/sing-box.start >/dev/null 2>&1
	clear
	sleep 1
elif [ \$menu == 5 ]
then
	pkill -f sing-box >/dev/null 2>&1
	pkill -f cloudflared-linux >/dev/null 2>&1
	rm -rf /opt/suoha /etc/local.d/cloudflared.start /etc/local.d/sing-box.start /usr/bin/suoha ~/.cloudflared
	echo "所有服务都卸载完成"
	echo "彻底删除授权记录"
	echo "请访问 https://dash.cloudflare.com/profile/api-tokens"
	echo "删除授权的 Argo Tunnel API Token 即可"
	exit 0
elif [ \$menu == 6 ]
then
	clear
	cat /opt/suoha/sb.txt
elif [ \$menu == 0 ]
then
	echo "退出成功"
	exit 0
fi
done
EOF
else
#创建命令链接 (Systemd版子菜单管理脚本)
cat>/opt/suoha/suoha.sh<<EOF
#!/bin/bash
clear
while true
do
echo "argo \$(systemctl status cloudflared.service 2>/dev/null | grep Active | awk '{print \$2 \$3}')"
echo "sing-box \$(systemctl status sing-box.service 2>/dev/null | grep Active | awk '{print \$2 \$3}')"
echo "1.管理TUNNEL"
echo "2.启动服务"
echo "3.停止服务"
echo "4.重启服务"
echo "5.卸载服务"
echo "6.查看当前v2ray链接"
echo "0.退出"
read -p "请选择菜单(默认0): " menu
if [ -z "\$menu" ]
then
	menu=0
fi
if [ \$menu == 1 ]
then
	clear
	while true
	do
		echo "ARGO TUNNEL当前已经绑定的服务如下"
		/opt/suoha/cloudflared-linux tunnel list
		echo "1.删除TUNNEL"
		echo "0.退出"
		read -p "请选择菜单(默认0): " tunneladmin
		if [ -z "\$tunneladmin" ]
		then
			tunneladmin=0
		fi
		if [ \$tunneladmin == 1 ]
		then
			read -p "请输入要删除的TUNNEL NAME: " tunnelname
			echo "断开TUNNEL \$tunnelname"
			/opt/suoha/cloudflared-linux tunnel cleanup \$tunnelname
			echo "删除TUNNEL \$tunnelname"
			/opt/suoha/cloudflared-linux tunnel delete \$tunnelname
		else
			break
		fi
	done
elif [ \$menu == 2 ]
then
	systemctl start cloudflared.service
	systemctl start sing-box.service
	clear
elif [ \$menu == 3 ]
then
	systemctl stop cloudflared.service
	systemctl stop sing-box.service
	clear
elif [ \$menu == 4 ]
then
	systemctl restart cloudflared.service
	systemctl restart sing-box.service
	clear
elif [ \$menu == 5 ]
then
	systemctl stop cloudflared.service >/dev/null 2>&1
	systemctl stop sing-box.service >/dev/null 2>&1
	systemctl disable cloudflared.service >/dev/null 2>&1
	systemctl disable sing-box.service >/dev/null 2>&1
	pkill -f sing-box >/dev/null 2>&1
	pkill -f cloudflared-linux >/dev/null 2>&1
	rm -rf /opt/suoha /lib/systemd/system/cloudflared.service /lib/systemd/system/sing-box.service /usr/bin/suoha ~/.cloudflared
	systemctl --system daemon-reload
	echo "所有服务都卸载完成"
	echo "彻底删除授权记录"
	echo "请访问 https://dash.cloudflare.com/profile/api-tokens"
	echo "删除授权的 Argo Tunnel API Token 即可"
	exit 0
elif [ \$menu == 6 ]
then
	clear
	cat /opt/suoha/sb.txt
elif [ \$menu == 0 ]
then
	echo "退出成功"
	exit 0
fi
done
EOF
fi
chmod +x /opt/suoha/suoha.sh
ln -sf /opt/suoha/suoha.sh /usr/bin/suoha
}

clear
echo "基于suoha.sh脚本修改，实现cloudflared sing-box功能"
echo "首次绑定ARGO服务后如果不想再次跳转网页绑定"
echo "将已经绑定的系统目录下的 /root/.cloudflared 文件夹以及内容"
echo "拷贝至新系统下同样的目录,会自动跳过登录验证"
echo -e "\n...............................................\n"
echo "1.安装服务"
echo "2.卸载服务"
echo "3.清空缓存"
echo -e "0.退出脚本\n"
read -p "请选择模式(默认1):" mode
if [ -z "$mode" ]
then
	mode=1
fi

if [ "$mode" == "1" ]
then
	read -p "请选择argo连接模式IPV4或者IPV6(输入4或6,默认4):" ips
	if [ -z "$ips" ]
	then
		ips=4
	fi
	if [ "$ips" != "4" ] && [ "$ips" != "6" ]
	then
		echo "请输入正确的argo连接模式"
		exit 1
	fi

	read -p "是否对特殊站点启用AimiliVPN住宅代理(输入0或1,默认0):" daili
	if [ -z "$daili" ]
	then
		daili=0
	fi

	if [ "$daili" == "1" ]
	then 
		if ! pgrep -f vpngate_manager.py > /dev/null; then
			echo "【警告】未检测到 AimiliVPN 运行状态，请安装后继续！"
			exit 1
		fi
	fi

	# 【修复位置】：获取本地ISP元数据必须前置，否则 installtunnel 拿不到 $isp 变量导致节点别名空白
	echo "正在获取本地网络元数据..."
	isp=$(curl -"$ips" -s https://speed.cloudflare.com/meta | awk -F\" '{print $26"-"$18"-"$30}' | sed -e 's/ /_/g')
	if [ -z "$isp" ]; then
		isp="ArgoSB-Node"
	fi

	if [ "$(grep -i PRETTY_NAME /etc/os-release | cut -d \" -f2 | awk '{print $1}')" == "Alpine" ]
	then
		pkill -f sing-box >/dev/null 2>&1
		pkill -f cloudflared-linux >/dev/null 2>&1
		rm -rf /opt/suoha /lib/systemd/system/cloudflared.service /lib/systemd/system/sing-box.service /usr/bin/suoha
	else
		systemctl stop cloudflared.service >/dev/null 2>&1
		systemctl stop sing-box.service >/dev/null 2>&1
		systemctl disable cloudflared.service >/dev/null 2>&1
		systemctl disable sing-box.service >/dev/null 2>&1
		pkill -f sing-box >/dev/null 2>&1
		pkill -f cloudflared-linux >/dev/null 2>&1
		rm -rf /opt/suoha /lib/systemd/system/cloudflared.service /lib/systemd/system/sing-box.service /usr/bin/suoha
		systemctl --system daemon-reload
	fi
	installtunnel
	cat /opt/suoha/sb.txt
	echo "服务安装完成,管理服务请运行命令 suoha"
elif [ "$mode" == "2" ]
then
	if [ "$(grep -i PRETTY_NAME /etc/os-release | cut -d \" -f2 | awk '{print $1}')" == "Alpine" ]
	then
		pkill -f sing-box >/dev/null 2>&1
		pkill -f cloudflared-linux >/dev/null 2>&1
		rm -rf /opt/suoha /lib/systemd/system/cloudflared.service /lib/systemd/system/sing-box.service /usr/bin/suoha
	else
		systemctl stop cloudflared.service >/dev/null 2>&1
		systemctl stop sing-box.service >/dev/null 2>&1
		systemctl disable cloudflared.service >/dev/null 2>&1
		systemctl disable sing-box.service >/dev/null 2>&1
		pkill -f sing-box >/dev/null 2>&1
		pkill -f cloudflared-linux >/dev/null 2>&1
		rm -rf /opt/suoha /lib/systemd/system/cloudflared.service /lib/systemd/system/sing-box.service /usr/bin/suoha ~/.cloudflared
		systemctl --system daemon-reload
	fi
	clear
	echo "所有服务都卸载完成"
	echo "彻底删除授权记录"
	echo "请访问 https://dash.cloudflare.com/profile/api-tokens"
	echo "删除授权的 Argo Tunnel API Token 即可"
elif [ "$mode" == "3" ]
then
	pkill -f sing-box >/dev/null 2>&1
	pkill -f cloudflared-linux >/dev/null 2>&1
	rm -rf sing-box cloudflared-linux sb.txt
	echo "缓存清空完成"
else
	echo "退出成功"
	exit 0
fi

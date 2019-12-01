SHELL_FOLDER=$(cd "$(dirname "$0")";pwd)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
SKYBLUE='\033[0;36m'
PLAIN='\033[0m'
getAbout() {
	echo ""
	echo " ========================================================= "
	echo " \                    Generate Script                    / "
	echo " \                   Created by CyouGuang                / "
	echo " ========================================================= "
	echo ""
	echo " Copyright (C) 2019 CyouGuang tobbcyg@gmail.com"
	echo -e " Version: ${GREEN}20191118${PLAIN} (2019.11.18)"
    echo -e " ${RED} \u5185\u90e8\u4f7f\u7528\uff0c\u8bf7\u52ff\u4f20\u64ad\u0021 ${PLAIN}"
	echo ""
}

getAbout

if [ ${1} ];then
    YYETS_USERNAME=${1}
else
    read -p "Please input username:" YYETS_USERNAME
fi
if [ ${2} ];then
    YYETS_PASSWORD=${2}
else
    read -p -s "Please input password ( Password can't see ):" YYETS_PASSWORD
fi
if [ ${3} ];then
    YYETS_UID=${3}
else
    read -p "Please input uid:" YYETS_UID
fi

read -p "Please input network speed ( kbps , zero isn't limit ) :" YYETS_SPEED

YYETS_PASSWORD_MD5=$(echo ${YYETS_PASSWORD}|tr -d '\n'|md5sum|tr -d ' -')
cat << EOF > yyets.env
YYETS_UID=${YYETS_UID}
YYETS_USERNAME=${YYETS_USERNAME}
YYETS_PASSWORD_MD5=${YYETS_PASSWORD_MD5}
YYETS_SPEED=${YYETS_SPEED}
EOF
CONFIG_FILE=${SHELL_FOLDER}'/yyets.env'
echo "***************************"
echo "账号:${YYETS_USERNAME}"
echo "密码MD5:${YYETS_PASSWORD_MD5}"
echo "UID:${YYETS_UID}"
echo "***************************"
#指定Mac前缀
echo '请输入Mac前缀(最后两位留空 例如:00:60:2F:E0:6C:C2 输入 00:60:2F:E0:6C 即可)'

read -p "[回车留空则自动生成(推荐)]:" MAC_PIRFX
if [ ! ${MAC_PIRFX} ];then
    MAC_PIRFX=$(printf '00:%02X:%02X:%02X:%02X' $[RANDOM%256] $[RANDOM%256] $[RANDOM%256] $[RANDOM%256])
fi
echo "你的机器Mac前缀是:${MAC_PIRFX}"

echo -e "${YELLOW}[warning]${PLAIN}为了避免冲突，请每次重新生成都使用不同序号"
echo -e "启动时将会创建:${RED}yyets_代号_机器批号${PLAIN}"
read -p "这是第几代设备?[单字母或单数字都行]:" GENERATION

read -p "请输入一次启动的机器数(建议不要超过30个):" LUNCH_NUM

if [ ! ${LUNCH_NUM} ];then
    LUNCH_NUM=10
fi

read -p "请输入启动失败重启策略(输入数字即可)[0:不重启(推荐),1:重启直至成功]:" RESTART_NUM

case $RESTART_NUM in
    0)  RESTART_STRATEGY='no'
    ;;
    1)  RESTART_STRATEGY='always'
    ;;
    *)  RESTART_STRATEGY='no'
    ;;
esac

#生成配置文件
read -p "请输入生成机器个数(建议大于100以上的重新建一个文件夹生成)(1-256):" MACHINE_NUM


echo -e "${YELLOW}请仔细核对以下配置信息!${PLAIN}"
echo "***************************"
echo "Mac前缀:${MAC_PIRFX}"
echo "设备代号:${GENERATION}"
echo "一次启动的机器数:${LUNCH_NUM}"
echo "重启策略:${RESTART_STRATEGY}"
echo "本次将会生成机器数:${MACHINE_NUM}"
echo "***************************"
read -p "生成配置[Y/n]:" READY_START

if [ $READY_START == 'n' ]; then
    echo -e "${RED}Good Bye!${PLAIN}"
    exit 0
fi

MACHINE_NUM=`expr ${MACHINE_NUM} - 1`
FOLDER_NUM=0
for i in $(seq 0 ${MACHINE_NUM})  
do
    CHECK_NUM=`expr $i % ${LUNCH_NUM}`
    if (( $CHECK_NUM == 0 ));then
        YYETS_FOLDER="${SHELL_FOLDER}/yyets_${GENERATION}_${FOLDER_NUM}"
        if [ ! -d "$YYETS_FOLDER" ]; then
            mkdir "$YYETS_FOLDER"
            mkdir "$YYETS_FOLDER/logs"
            echo "创建文件夹:$YYETS_FOLDER"
        fi
        FOLDER_NUM=`expr ${FOLDER_NUM} + 1`
    fi
    
    YYETS_MAC=$(printf "${MAC_PIRFX}:%02X" ${i})
    NUM=$(expr $LUNCH_NUM - 1)
    YYETS_SERVICE=$(cat << EOF
${YYETS_SERVICE}
  yyets_${GENERATION}_${i}:
    image: cyouguang/miner
    env_file: ${CONFIG_FILE}
    volumes:
      - ./logs:/root/yyets/runlogs
      - yyets_data:/root/yydata/
    mac_address: ${YYETS_MAC}
    restart: "${RESTART_STRATEGY}"
    privileged: true
EOF)
    if (( $CHECK_NUM == $NUM )) || (( $i == $MACHINE_NUM ));then
cat << EOF > ${YYETS_FOLDER}/docker-compose.yml
version: '3'
services:
${YYETS_SERVICE}
volumes:
  yyets_data:
EOF
    YYETS_SERVICE=''
    fi
done

# 输出一键运行脚本
LUNCH_NUM=`expr ${FOLDER_NUM} - 1`
cat << EOF > lunch.sh
for i in \$(seq 0 ${LUNCH_NUM})
do
    echo "正在进入\${i}号文件夹"
    cd ${SHELL_FOLDER}/yyets_${GENERATION}_\${i}
    sudo docker-compose up -d
    echo "等待1分钟"
    sleep 60
done
echo "启动完成"
EOF

chmod +x lunch.sh

cat << EOF > down.sh
for i in \$(seq 0 ${LUNCH_NUM})
do
    echo "正在进入\${i}号文件夹"
    cd ${SHELL_FOLDER}/yyets_${GENERATION}_\${i}
    sudo docker-compose down
    echo "等待5s"
    sleep 5
done
echo "关闭完成"
EOF

chmod +x down.sh

echo "配置生成完成,你可以使用以下命令来一键关闭"
echo "sudo ./down.sh"

echo "配置生成完成,你可以使用以下命令来一键启动"
echo "sudo ./lunch.sh"
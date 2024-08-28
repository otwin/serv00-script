#!/bin/bash

# ANSI颜色码
GREEN=''
NC=''  # 恢复默认颜色

# Function to save config.json
save_config() {
    # local port=$1
    local port=31164
    if [[ ! -f ~/domains/bigice.serv00.net/config.json ]]; then
        uuid="d1d1e4c9-4e3b-4b6b-817a-7c77013cef1d"
        cat <<EOL > ~/domains/bigice.serv00.net/config.json
{
    "uuid": "$uuid",
    "port": $port
}
EOL
        echo "生成config.json文件。"
    else
        # Update the port in config.json if it exists
        jq --arg port "$port" '.port = ($port | tonumber)' ~/domains/bigice.serv00.net/config.json > ~/domains/bigice.serv00.net/config_tmp.json && mv ~/domains/bigice.serv00.net/config_tmp.json ~/domains/bigice.serv00.net/config.json
        echo "config.json文件已存在，端口号已更新。"
    fi
}

# Function to deploy vless
deploy_vless() {
    #local port=${1:-3000}  # Default port is 3000 if not provided
    local port=31164
    # 修改端口号
    save_config "$port"
    # 安装依赖
    npm install
    # 启动vless项目
    ~/.npm-global/bin/pm2 start ~/domains/bigice.serv00.net/app.js --name vless
    # 保存pm2进程状态
    ~/.npm-global/bin/pm2 save
    # ANSI颜色码
    echo -e "端口号: ${GREEN}${port}${NC}"
    echo -e "UUID: ${GREEN}${uuid}${NC}"
    echo -e "域名: ${GREEN}bigice.serv00.net${NC}"
    echo -e "vless进程维护定时任务脚本: ${GREEN}cd ~/domains/bigice.serv00.net && ./check_vless.sh${NC}"
    echo -e "VLESS节点信息: ${GREEN}vless://${uuid}@$USER.serv00.net:${port}?flow=&security=none&encryption=none&type=ws&host=$USER.serv00.net&path=/&sni=&fp=&pbk=&sid=#$USER.serv00.vless${NC}"
}

# 启动pm2 vless进程
start_pm2_vless_process() {
    echo "正在启动pm2 vless进程..."
    ~/.npm-global/bin/pm2 start ~/domains/bigice.serv00.net/app.js --name vless
    echo -e "${GREEN}pm2 vless进程已启动。${NC}"
}
# 检查vless的状态
check_vless_status() {
    status=$(~/.npm-global/bin/pm2 status vless | grep -w 'vless' | awk '{print $18}')
    if [[ "$status" == "online" ]]; then
        echo "vless进程正在运行。"
    else
        echo "vless进程未运行或已停止，正在重启..."
        ~/.npm-global/bin/pm2 restart vless
        echo -e "${GREEN}vless进程已重启。${NC}"
    fi
}
# 检查是否有pm2 vless快照
check_pm2_vless_snapshot() {
    if [[ -f ~/.pm2/dump.pm2 ]]; then
        echo "检测到pm2 vless快照，正在恢复..."
        ~/.npm-global/bin/pm2 resurrect
        echo -e "${GREEN}pm2 vless快照已恢复。${NC}"
        check_vless_status
    else
        echo "未检测到pm2 vless快照，启动vless进程..."
        start_pm2_vless_process
    fi
}


# 检查pm2 vless的状态
check_pm2_vless_status() {
    ~/.npm-global/bin/pm2 describe vless &>/dev/null
    if [[ $? -eq 0 ]]; then
        check_vless_status
    else
        echo "未找到pm2 vless进程，检查是否有快照..."
        check_pm2_vless_snapshot
    fi
}
# 主函数
main() {
    local port=31164  # Default port
    port_provided=false  # Flag to check if port is provided

    while getopts ":p:" opt; do
        case $opt in
            p)
                port=$OPTARG
                port_provided=true
                ;;
            *)
                echo "无效参数"; exit 1 ;;
        esac
    done
    shift $((OPTIND -1))

    if [ "$port_provided" = true ]; then
        echo "正在安装vless..."
        deploy_vless "$port"
    else
        echo "没有提供-p参数，跳过vless安装。"
        # 读取 config.json 中的 uuid 和 port
        if [[ -f config.json ]]; then
            uuid=$(jq -r '.uuid' config.json)
            port=$(jq -r '.port' config.json)
            echo -e "UUID: ${uuid}"
            echo -e "Port: ${port}"
            echo -e "域名: bigice.serv00.net"
            echo -e "VLESS节点信息: vless://${uuid}@bigice.serv00.net:${port}?flow=&security=none&encryption=none&type=ws&host=bigice.serv00.net&path=/&sni=&fp=&pbk=&sid=#bigice.serv00.vless"

        else
            echo -e "config.json 文件不存在或格式错误。"
        fi
        echo "开始检查pm2 vless进程..."
        check_pm2_vless_status
    fi


}

# 执行主函数
main "$@"

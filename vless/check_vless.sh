#!/bin/bash

# Function to save config.json
save_config() {
    local port=$1
    if [[ ! -f ~/domains/$USER.serv00.net/config.json ]]; then
        uuid="d1d1e4c9-4e3b-4b6b-817a-7c77013cef1d"
        
        cat <<EOL > ~/domains/$USER.serv00.net/config.json
{
    "uuid": "$uuid",
    "port": $port
}
EOL
        echo "生成config.json文件。"
    else
        # Update the port in config.json if it exists
        jq --arg port "$port" '.port = ($port | tonumber)' ~/domains/$USER.serv00.net/config.json > ~/domains/$USER.serv00.net/config_tmp.json && mv ~/domains/$USER.serv00.net/config_tmp.json ~/domains/$USER.serv00.net/config.json
        echo "config.json文件已存在，端口号已更新。"
    fi
}

# Function to deploy vless
deploy_vless() {
    local port=${1:-31164} # Default port is 31164 if not provided
    # 修改端口号
    save_config "$port"
    # 安装依赖
    npm install
    # 启动vless项目
    ~/.npm-global/bin/pm2 start ~/domains/$USER.serv00.net/app.js --name vless
    # 保存pm2进程状态
    ~/.npm-global/bin/pm2 save
    # ANSI颜色码
    echo -e "端口号: ${port}"
    echo -e "UUID: ${uuid}"
    echo -e "域名: $USER.serv00.net"
    echo -e "vless进程维护定时任务脚本: cd ~/domains/$USER.serv00.net && ./check_vless.sh"
    echo -e "VLESS节点信息: vless://${uuid}@$USER.serv00.net:${port}?flow=&security=none&encryption=none&type=ws&host=$USER.serv00.net&path=/&sni=&fp=&pbk=&sid=#$USER.serv00.vless"
}

# 启动pm2 vless进程
start_pm2_vless_process() {
    echo "正在启动pm2 vless进程..."
    ~/.npm-global/bin/pm2 start ~/domains/$USER.serv00.net/app.js --name vless
    echo -e "pm2 vless进程已启动。"
}
# 检查vless的状态
check_vless_status() {
    status=$(~/.npm-global/bin/pm2 status vless | grep -w 'vless' | awk '{print $18}')
    if [[ "$status" == "online" ]]; then
        echo "vless进程正在运行。"
    else
        echo "vless进程未运行或已停止，正在重启..."
        ~/.npm-global/bin/pm2 restart vless
        echo -e "vless进程已重启。"
    fi
}
# 检查是否有pm2 vless快照
check_pm2_vless_snapshot() {
    if [[ -f ~/.pm2/dump.pm2 ]]; then
        echo "检测到pm2 vless快照，正在恢复..."
        ~/.npm-global/bin/pm2 resurrect
        echo -e "pm2 vless快照已恢复。"
        check_vless_status
    else
        echo "未检测到pm2 vless快照，启动vless进程..."
        start_pm2_vless_process
    fi
}


# 检查pm2 vless的状态
check_pm2_vless_status() {

    vless_status=$(~/.npm-global/bin/pm2 describe vless --no-color | grep "status" | awk '{print $4}')

    if [[ -n $vless_status && $vless_status == "online" ]]; then
        check_vless_status
    else
        if [[ -z $vless_status ]]; then
            echo "未找到pm2 vless进程，检查是否有快照..."
            check_pm2_vless_snapshot
        else
            echo "vless进程存在，但状态为 $vless_status"
            check_vless_status
        fi
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
        echo "vless参数："
        # 读取 config.json 中的 uuid 和 port
        if [[ -f config.json ]]; then
            uuid=$(jq -r '.uuid' config.json)
            port=$(jq -r '.port' config.json)
            echo -e "UUID: ${uuid}"
            echo -e "Port: ${port}"
            echo -e "域名: $USER.serv00.net"
            echo -e "VLESS节点信息: vless://${uuid}@$USER.serv00.net:${port}?flow=&security=none&encryption=none&type=ws&host=$USER.serv00.net&path=/&sni=&fp=&pbk=&sid=#$USER.serv00.vless"

        else
            echo -e "config.json 文件不存在或格式错误。"
        fi
        echo "开始检查pm2 vless进程..."
        check_pm2_vless_status
    fi


}

# 执行主函数
main "$@"

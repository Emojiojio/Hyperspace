#!/bin/bash

# 脚本保存路径
SCRIPT_PATH="$HOME/Hyperspace.sh"
POINTS_HISTORY_LOG="/root/points_history.log"

# 如果传入 "stopall" 参数，终止所有监控
if [ "$1" == "stopall" ]; then
    echo "正在终止所有监控进程..."
    pkill -f monitor.sh 2>/dev/null
    pkill -f points_monitor.sh 2>/dev/null
    pkill -f hourly_points.sh 2>/dev/null
    echo "所有监控进程已停止"
    exit 0
fi

# 检查并安装 screen
function check_and_install_screen() {
    if ! command -v screen &> /dev/null; then
        echo "screen 未安装，正在安装..."
        apt update && apt install -y screen
    else
        echo "screen 已安装。"
    fi
}

# 主菜单函数（新增停止所有监控选项）
function main_menu() {
    while true; do
        clear
        echo "脚本由大赌社区哈哈哈哈编写，推特 @ferdie_jhovie，免费开源，请勿相信收费"
        echo "如有问题，可联系推特，仅此只有一个号"
        echo "================================================================"
        echo "退出脚本，请按键盘 ctrl + C 退出即可"
        echo "请选择要执行的操作:"
        echo "1. 部署hyperspace节点"
        echo "2. 查看日志"
        echo "3. 查看积分"
        echo "4. 删除节点（停止节点）"
        echo "5. 启用日志监控"
        echo "6. 查看使用的私钥"
        echo "7. 查看aios daemon状态"
        echo "8. 启用积分监控"
        echo "9. 启用每小时积分记录"
        echo "10. 停止所有监控"  # 新增选项
        echo "11. 退出脚本"      # 原10改为11
        echo "================================================================"
        read -p "请输入选择 (1-11): " choice

        case $choice in
            1)  deploy_hyperspace_node ;;
            2)  view_logs ;; 
            3)  view_points ;;
            4)  delete_node ;;
            5)  start_log_monitor ;;
            6)  view_private_key ;;
            7)  view_status ;;
            8)  start_points_monitor ;;
            9)  start_hourly_points_record ;;
            10) stop_all_monitors ;;  # 新增选项处理
            11) exit_script ;;
            *)  echo "无效选择，请重新输入！"; sleep 2 ;;
        esac
    done
}

# 部署hyperspace节点
function deploy_hyperspace_node() {
    echo "正在执行安装命令：curl https://download.hyper.space/api/install | bash"
    curl https://download.hyper.space/api/install | bash

    NEW_PATH=$(bash -c 'source /root/.bashrc && echo $PATH')
    export PATH="$NEW_PATH"

    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        export PATH="$HOME/.local/bin:$PATH"
    fi

    if [[ ":$PATH:" != *":/root/.aios:"* ]]; then
        export PATH="/root/.aios:$PATH"
    fi

    echo "当前 PATH: $PATH"

    if ! command -v /root/.aios/aios-cli &> /dev/null; then
        echo "aios-cli 命令未找到，正在重试..."
        sleep 3
        export PATH="$PATH:/root/.local/bin"
        if ! command -v /root/.aios/aios-cli &> /dev/null; then
            echo "无法找到 aios-cli 命令，请手动运行 'source /root/.bashrc' 后重试"
            read -n 1 -s -r -p "按任意键返回主菜单..."
            return
        fi
    fi

    read -p "请输入屏幕名称 (默认值: hyper): " screen_name
    screen_name=${screen_name:-hyper}
    echo "使用的屏幕名称是: $screen_name"

    echo "检查并清理现有的 '$screen_name' 屏幕会话..."
    screen -ls | grep "$screen_name" &>/dev/null
    if [ $? -eq 0 ]; then
        echo "找到现有的 '$screen_name' 屏幕会话，正在停止并删除..."
        screen -S "$screen_name" -X quit
        sleep 2
    else
        echo "没有找到现有的 '$screen_name' 屏幕会话。"
    fi

    echo "创建一个名为 '$screen_name' 的屏幕会话..."
    screen -S "$screen_name" -dm

    echo "在屏幕会话 '$screen_name' 中运行 'aios-cli start' 命令..."
    screen -S "$screen_name" -X stuff "/root/.aios/aios-cli start\n"

    sleep 5
    echo "退出屏幕会话 '$screen_name'..."
    screen -S "$screen_name" -X detach
    sleep 5

    echo "当前 PATH: $PATH"

    echo "请输入你的私钥（按 CTRL+D 结束）："
    cat > my.pem

    echo "正在使用 my.pem 文件运行 import-keys 命令..."
    /root/.aios/aios-cli hive import-keys ./my.pem
    sleep 5

    model="hf:TheBloke/phi-2-GGUF:phi-2.Q4_K_M.gguf"
    echo "正在通过命令 '/root/.aios/aios-cli models add' 添加模型..."
    while true; do
        if /root/.aios/aios-cli models add "$model"; then
            echo "模型添加成功并且下载完成！"
            break
        else
            echo "添加模型时发生错误，正在重试..."
            sleep 3
        fi
    done

    echo "正在登录并选择等级..."
    /root/.aios/aios-cli hive login

    echo "请选择等级（1-5）："
    select tier in 1 2 3 4 5; do
        case $tier in
            1|2|3|4|5)
                echo "你选择了等级 $tier"
                /root/.aios/aios-cli hive select-tier $tier
                break
                ;;
            *)  echo "无效的选择，请输入 1 到 5 之间的数字。" ;;
        esac
    done

    /root/.aios/aios-cli hive connect
    sleep 5

    echo "使用 '/root/.aios/aios-cli kill' 停止 'aios-cli start' 进程..."
    /root/.aios/aios-cli kill

    echo "在屏幕会话 '$screen_name' 中运行 '/root/.aios/aios-cli start --connect'..."
    screen -S "$screen_name" -X stuff "/root/.aios/aios-cli start --connect >> /root/aios-cli.log 2>&1\n"

    echo "部署hyperspace节点完成，系统已恢复到后台。"
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 查看日志
function view_logs() {
    echo "正在查看日志..."
    LOG_FILE="/root/aios-cli.log"
    if [ -f "$LOG_FILE" ]; then
        echo "显示日志的最后 200 行:"
        tail -n 200 "$LOG_FILE"
    else
        echo "日志文件不存在: $LOG_FILE"
    fi
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 查看积分
function view_points() {
    echo "正在查看当前积分..."
    source /root/.bashrc
    aios-cli hive points
    echo ""
    echo "积分历史记录保存在: $POINTS_HISTORY_LOG"
    if [ -f "$POINTS_HISTORY_LOG" ]; then
        echo "显示最近10次积分记录:"
        tail -n 10 "$POINTS_HISTORY_LOG"
    else
        echo "暂无历史记录"
    fi
    sleep 5
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 删除节点
function delete_node() {
    echo "正在使用 'aios-cli kill' 停止节点..."
    aios-cli kill
    sleep 2
    echo "'aios-cli kill' 执行完成，节点已停止。"
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 启用日志监控
function start_log_monitor() {
    echo "启动日志监控..."
    pkill -f monitor.sh 2>/dev/null
    sleep 2

    cat > /root/monitor.sh << 'EOL'
#!/bin/bash
LOG_FILE="/root/aios-cli.log"
SCREEN_NAME="hyper"
LAST_RESTART=$(date +%s)
MIN_RESTART_INTERVAL=300

while true; do
    current_time=$(date +%s)
    if (tail -n 4 "$LOG_FILE" | grep -q "Last pong received.*Sending reconnect signal" || \
        tail -n 4 "$LOG_FILE" | grep -q "Failed to authenticate" || \
        tail -n 4 "$LOG_FILE" | grep -q "Failed to connect to Hive" || \
        tail -n 4 "$LOG_FILE" | grep -q "Another instance is already running" || \
        tail -n 4 "$LOG_FILE" | grep -q "\"message\": \"Internal server error\"" || \
        tail -n 4 "$LOG_FILE" | grep -q "thread 'main' panicked at aios-cli/src/main.rs:181:39: called \`Option::unwrap()\` on a \`None\` value") && \
       [ $((current_time - LAST_RESTART)) -gt $MIN_RESTART_INTERVAL ]; then
        echo "$(date): 检测到错误，正在重启服务..." >> /root/monitor.log
        screen -S "$SCREEN_NAME" -X stuff $'\003'
        sleep 5
        screen -S "$SCREEN_NAME" -X stuff "aios-cli kill\n"
        sleep 5
        echo "$(date): 清理旧日志..." > "$LOG_FILE"
        screen -S "$SCREEN_NAME" -X stuff "aios-cli start --connect >> /root/aios-cli.log 2>&1\n"
        LAST_RESTART=$current_time
        echo "$(date): 服务已重启" >> /root/monitor.log
    fi
    sleep 30
done
EOL

    chmod +x /root/monitor.sh
    nohup /root/monitor.sh > /root/monitor.log 2>&1 &
    echo "日志监控已启动，后台运行中。"
    echo "可以通过查看 /root/monitor.log 来检查监控状态"
    sleep 2
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 查看使用的私钥
function view_private_key() {
    echo "正在查看使用的私钥..."
    aios-cli hive whoami
    sleep 2
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 查看aios daemon状态
function view_status() {
    echo "正在查看aios状态..."
    aios-cli status
    sleep 2
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 启用积分监控
function start_points_monitor() {
    echo "启动积分监控..."
    pkill -f points_monitor.sh 2>/dev/null
    sleep 2

    cat > /root/points_monitor.sh << 'EOL'
#!/bin/bash
LOG_FILE="/root/aios-cli.log"
SCREEN_NAME="hyper"
LAST_POINTS=0
MIN_RESTART_INTERVAL=300

while true; do
    CURRENT_POINTS=$(aios-cli hive points | grep -o '[0-9]\+' || echo "0")
    if [ "$CURRENT_POINTS" -eq "$LAST_POINTS" ]; then
        echo "$(date): 积分没有增加，正在重启服务..." >> /root/points_monitor.log
        screen -S "$SCREEN_NAME" -X stuff $'\003'
        sleep 5
        screen -S "$SCREEN_NAME" -X stuff "aios-cli kill\n"
        sleep 5
        echo "$(date): 清理旧日志..." > "$LOG_FILE"
        screen -S "$SCREEN_NAME" -X stuff "aios-cli start --connect >> /root/aios-cli.log 2>&1\n"
        LAST_POINTS=$CURRENT_POINTS
    else
        LAST_POINTS=$CURRENT_POINTS
    fi
    sleep 7200
done
EOL

    chmod +x /root/points_monitor.sh
    nohup /root/points_monitor.sh > /root/points_monitor.log 2>&1 &
    echo "积分监控已启动，后台运行中。"
    echo "可以通过查看 /root/points_monitor.log 来检查监控状态"
    sleep 2
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 启用每小时积分记录
function start_hourly_points_record() {
    echo "启动每小时积分记录..."
    pkill -f hourly_points.sh 2>/dev/null
    sleep 2

    cat > /root/hourly_points.sh << 'EOL'
#!/bin/bash
POINTS_HISTORY_LOG="/root/points_history.log"

if [ ! -f "$POINTS_HISTORY_LOG" ]; then
    echo "时间,Points" > "$POINTS_HISTORY_LOG"
fi

while true; do
    CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    CURRENT_POINTS=$(aios-cli hive points | grep "Points" | awk '{print $2}' || echo "无法获取")
    echo "$CURRENT_TIME,$CURRENT_POINTS" >> "$POINTS_HISTORY_LOG"
    echo "$CURRENT_TIME: 已记录积分: $CURRENT_POINTS"
    sleep 3600
done
EOL

    chmod +x /root/hourly_points.sh
    nohup /root/hourly_points.sh > /root/hourly_points_record.log 2>&1 &
    echo "每小时积分记录已启动，后台运行中。"
    echo "积分数据将保存到: $POINTS_HISTORY_LOG"
    echo "可以通过查看 /root/hourly_points_record.log 检查运行状态"
    sleep 2
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 停止所有监控（新增功能）
function stop_all_monitors() {
    echo "正在终止所有监控进程..."
    pkill -f monitor.sh 2>/dev/null
    pkill -f points_monitor.sh 2>/dev/null
    pkill -f hourly_points.sh 2>/dev/null
    echo "所有监控进程已停止"
    sleep 2
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 退出脚本
function exit_script() {
    echo "退出脚本..."
    exit 0
}

# 调用主菜单函数
main_menu

#!/bin/bash
# OpenClaw 时光机 - 备份与恢复
# Usage: claw-time-machine [backup|restore|list] [file]

set -e

ACTION=${1:-backup}
BACKUP_FILE="$2"
OPENCLAW_DIR="$HOME/.openclaw"
BACKUP_DIR="$HOME/.claw-time-machine"

# 灵魂文件列表
SOUL_FILES=(
    "workspace"
    "credentials"
    "telegram"
    "skills"
    "cron"
    "openclaw.json"
    "identity"
)

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}ℹ${NC}  $1"; }
log_ok() { echo -e "${GREEN}✓${NC}  $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC}  $1"; }
log_error() { echo -e "${RED}✗${NC}  $1"; }

ensure_backup_dir() {
    mkdir -p "$BACKUP_DIR"
}

generate_filename() {
    echo "openclaw-soul-$(date +%Y%m%d-%H%M%S).tar.gz"
}

backup() {
    ensure_backup_dir
    local output_file="${BACKUP_DIR}/${BACKUP_FILE:-$(generate_filename)}"
    
    log_info "正在打包灵魂..."
    
    # 创建临时清单
    local manifest=$(mktemp)
    for item in "${SOUL_FILES[@]}"; do
        if [[ -e "$OPENCLAW_DIR/$item" ]]; then
            echo "$item" >> "$manifest"
        fi
    done
    
    # 打包
    tar czf "$output_file" -C "$OPENCLAW_DIR" -T "$manifest" 2>/dev/null
    rm "$manifest"
    
    local size=$(du -h "$output_file" | cut -f1)
    log_ok "备份完成: $output_file ($size)"
}

restore() {
    if [[ -z "$BACKUP_FILE" ]]; then
        log_error "请指定备份文件或序号"
        echo ""
        echo "💡 用法:"
        echo "   claw-time-machine restore 1          # 用序号恢复"
        echo "   claw-time-machine restore <文件名>   # 用文件名恢复"
        echo ""
        list_backups
        exit 1
    fi
    
    local full_path="$BACKUP_FILE"
    
    # 检查是否是纯数字序号（如 "1" 或 "[1]"）
    local idx=$(echo "$BACKUP_FILE" | sed 's/\[//g; s/\]//g')
    if [[ "$idx" =~ ^[0-9]+$ ]]; then
        # 是序号，查找对应文件
        local file_count=0
        for file in "$BACKUP_DIR"/openclaw-soul-*.tar.gz; do
            if [[ -f "$file" ]]; then
                file_count=$((file_count + 1))
                if [[ "$file_count" -eq "$idx" ]]; then
                    full_path="$file"
                    break
                fi
            fi
        done
        
        if [[ "$full_path" == "$BACKUP_FILE" ]]; then
            log_error "无效的序号: $idx"
            list_backups
            exit 1
        fi
        
        log_info "选中备份 #$idx: $(basename "$full_path")"
    elif [[ ! -f "$full_path" && -f "${BACKUP_DIR}/${BACKUP_FILE}" ]]; then
        # 尝试在备份目录查找
        full_path="${BACKUP_DIR}/${BACKUP_FILE}"
    fi
    
    if [[ ! -f "$full_path" ]]; then
        log_error "备份文件不存在: $BACKUP_FILE"
        exit 1
    fi
    
    log_warn "这会覆盖现有的 OpenClaw 配置"
    read -p "继续? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        log_info "取消恢复"
        exit 0
    fi
    
    # 停止服务
    if [[ -f "$OPENCLAW_DIR/bin/openclaw" ]]; then
        log_info "停止 OpenClaw 服务..."
        "$OPENCLAW_DIR/bin/openclaw" gateway stop 2>/dev/null || true
    fi
    
    # 安全备份当前灵魂（不是整个 .openclaw）
    if [[ -d "$OPENCLAW_DIR" ]]; then
        local safety="${OPENCLAW_DIR}.bak.$(date +%s)"
        log_info "安全备份当前配置到: $safety"
        cp -r "$OPENCLAW_DIR" "$safety"
    fi
    
    # 清理现有的灵魂文件（避免残留）
    log_info "清理现有配置..."
    for item in "${SOUL_FILES[@]}"; do
        if [[ -e "$OPENCLAW_DIR/$item" ]]; then
            rm -rf "$OPENCLAW_DIR/$item"
        fi
    done
    
    # 恢复灵魂
    log_info "正在恢复..."
    tar xzf "$full_path" -C "$OPENCLAW_DIR"
    
    log_ok "恢复完成"
    log_info "启动服务: ~/.openclaw/bin/openclaw gateway start"
    log_info "如需回滚: cp -r $safety ~/.openclaw"
}

list_backups() {
    ensure_backup_dir
    
    local count=0
    local total_size=0
    local idx=1
    
    # 检查是否有备份
    if ! ls "$BACKUP_DIR"/openclaw-soul-*.tar.gz 1> /dev/null 2>&1; then
        echo ""
        echo "📭 暂无备份"
        echo ""
        echo "💡 创建备份: claw-time-machine backup"
        return 0
    fi
    
    echo ""
    echo "📦 OpenClaw 备份列表"
    echo "════════════════════════════════════════════════════"
    echo ""
    
    for file in "$BACKUP_DIR"/openclaw-soul-*.tar.gz; do
        if [[ -f "$file" ]]; then
            local filename=$(basename "$file")
            local size=$(du -h "$file" | cut -f1)
            local size_bytes=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
            total_size=$((total_size + size_bytes))
            
            # 从文件名提取日期时间: 20260331-004110 → 2026-03-31 00:41:10
            local datetime_raw=$(echo "$filename" | grep -oE '[0-9]{8}-[0-9]{6}')
            local date_part=$(echo "$datetime_raw" | cut -c1-4)-$(echo "$datetime_raw" | cut -c5-6)-$(echo "$datetime_raw" | cut -c7-8)
            local time_part=$(echo "$datetime_raw" | cut -c10-11):$(echo "$datetime_raw" | cut -c12-13):$(echo "$datetime_raw" | cut -c14-15)
            local datetime="$date_part $time_part"
            
            echo "  [$idx] 📅 $datetime  💾 $size"
            echo ""
            idx=$((idx + 1))
            count=$((count + 1))
        fi
    done
    
    echo "════════════════════════════════════════════════════"
    
    # 总大小格式化
    local total_size_human
    if command -v numfmt &>/dev/null; then
        total_size_human=$(numfmt --to=iec "$total_size")
    else
        if [[ $total_size -gt 1073741824 ]]; then
            total_size_human="$(echo "scale=2; $total_size/1073741824" | bc)G"
        elif [[ $total_size -gt 1048576 ]]; then
            total_size_human="$(echo "scale=2; $total_size/1048576" | bc)M"
        elif [[ $total_size -gt 1024 ]]; then
            total_size_human="$(echo "scale=1; $total_size/1024" | bc)K"
        else
            total_size_human="${total_size}B"
        fi
    fi
    
    echo "📊 共 $count 个备份，总计 $total_size_human"
    echo ""
    echo "💡 恢复备份: claw-time-machine restore <序号或文件名>"
}

migrate() {
    local target_host="$BACKUP_FILE"
    if [[ -z "$target_host" ]]; then
        log_error "请指定目标服务器"
        echo "用法: claw-time-machine migrate user@new-server"
        exit 1
    fi
    
    log_info "一键迁移到: $target_host"
    
    # 先备份
    local filename=$(generate_filename)
    BACKUP_FILE="$filename" backup
    local full_path="${BACKUP_DIR}/${filename}"
    
    # 传输
    log_info "传输备份到目标服务器..."
    scp "$full_path" "${target_host}:~/"
    
    # 在目标服务器执行恢复
    log_info "在目标服务器安装并恢复..."
    ssh "$target_host" "
        if ! command -v openclaw &>/dev/null; then
            echo '安装 OpenClaw...'
            curl -fsSL https://openclaw.ai/install.sh | bash
        fi
        ~/.openclaw/skills/time-machine/scripts/claw-time-machine restore ~/$filename
        ~/.openclaw/bin/openclaw gateway start
    "
    
    log_ok "迁移完成!"
}

# 主入口
case "$ACTION" in
    backup)
        backup
        ;;
    restore)
        restore
        ;;
    list)
        list_backups
        ;;
    migrate)
        migrate
        ;;
    *)
        echo ""
        echo "🕐 OpenClaw 时光机"
        echo "════════════════════════════════════════════════════"
        echo ""
        echo "📋 命令:"
        echo ""
        echo "  📝 claw-time-machine backup"
        echo "     创建备份"
        echo ""
        echo "  📋 time-machine list"
        echo "     列出所有备份"
        echo ""
        echo "  ⏪ claw-time-machine restore <序号或文件名>"
        echo "     从备份恢复"
        echo "     例: claw-time-machine restore 1"
        echo "     例: claw-time-machine restore openclaw-soul-20260331.tar.gz"
        echo ""
        echo "  🚚 claw-time-machine migrate <user@host>"
        echo "     一键迁移到新服务器"
        echo "     例: claw-time-machine migrate root@192.168.1.100"
        echo ""
        echo "════════════════════════════════════════════════════"
        exit 1
        ;;
esac

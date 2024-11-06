#!/bin/bash
# 备份脚本 ./backup_script.sh <固定密钥> <backup_filename> <sftp_ip> <sftp_user> <sftp_password> <jenkins_file_dir>

# 固定的密钥（与Java中的FIXED_KEY相同）
FIXED_KEY="$1"  # 16字节（128位）
aes_decrypt() {
    local encrypted_data="$1"
    # 解密数据并返回
    decrypted_data=$(echo "$encrypted_data" | base64 -d | openssl enc -d -aes-128-ecb -K $(echo -n "$FIXED_KEY" | od -An -tx1 | tr -d ' \n') 2>/dev/null)
    # 返回解密后的数据
    echo "$decrypted_data"
}

# 接收参数
BACKUP_FILENAME=$(aes_decrypt $2)
SFTP_IP=$(aes_decrypt $3)
SFTP_USER=$(aes_decrypt $4)
SFTP_PASSWORD=$(aes_decrypt $5)
JENKINS_FILE_DIR=$(aes_decrypt $6)

ERRTEMP=""
ERRLOG=""
RESULT='{"code":"%s","errLog":"%s","fileSize":%d}'

# 创建 /tmp/jenkins/power_backups 目录
if [ ! -d "/tmp/jenkins/power_backups" ]; then
    ERRLOG=$(mkdir -p /tmp/jenkins/power_backups 2>&1)
    if [ $? -ne 0 ]; then
        ERRTEMP=$(echo "错误：无法创建目录 /tmp/jenkins/power_backups。日志：${ERRLOG}" | base64 -w 0)
        echo $(printf "$RESULT" "-1" "$ERRTEMP" "0")
        exit 1
    fi
fi

# 压缩/var/jenkins_home/目录下的文件到/tmp/备份文件名
ERRLOG=$(tar --exclude='plugins.tar.gz' --exclude='plugins' --exclude='casc_configs' --exclude='backup.sh' --exclude='recover.sh' --exclude='.[^/]*' -czf /tmp/jenkins/power_backups/${BACKUP_FILENAME} -C /var/jenkins_home/ ./ 2>&1)
if [ $? -ne 0 ]; then
    ERRTEMP=$(echo "错误：压缩备份文件${BACKUP_FILENAME}失败。日志：${ERRLOG}" | base64 -w 0)
    echo $(printf "$RESULT" "-1" "$ERRTEMP" "0")
    exit 1
fi

# 获取压缩文件的字节大小
FILE_SIZE=$(stat -c%s /tmp/jenkins/power_backups/${BACKUP_FILENAME})

# 使用SFTP创建目录并上传文件
ERRLOG=$(sshpass -p "$SFTP_PASSWORD" sftp -oBatchMode=no -o StrictHostKeyChecking=no -b - $SFTP_USER@$SFTP_IP <<EOF 2>&1
put /tmp/jenkins/power_backups/${BACKUP_FILENAME} ${JENKINS_FILE_DIR}${BACKUP_FILENAME}
bye
EOF
)
if [ $? -ne 0 ]; then
    ERRTEMP=$(echo "错误：上传备份文件${BACKUP_FILENAME}失败。日志：${ERRLOG}" | base64 -w 0)
    echo $(printf "$RESULT" "-1" "$ERRTEMP" "0")
    exit 1
fi

# 删除本地的备份文件
ERRLOG=$(rm -f /tmp/jenkins/power_backups/${BACKUP_FILENAME} 2>&1)
if [ $? -ne 0 ]; then
    ERRTEMP=$(echo "错误：删除本地的备份文件${BACKUP_FILENAME}失败。日志：${ERRLOG}" | base64 -w 0)
    echo $(printf "$RESULT" "-1" "$ERRTEMP" "0")
    exit 1
fi

echo $(printf "$RESULT" "0" "" "$FILE_SIZE")

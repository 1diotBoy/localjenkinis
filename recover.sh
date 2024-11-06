#!/bin/bash
# 恢复脚本 ./restore_script.sh <固定密钥> <backup_filename> <sftp_base_url> <jenkins_file_dir>

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
SFTP_BASE_URL_INNER=$(aes_decrypt $3)
JENKINS_FILE_DIR=$(aes_decrypt $4)

ERRTEMP=""
ERRLOG=""
RESULT='{"code":"%s","errLog":"%s","fileSize":%d}'

# 第一步：检测 /var/jenkins/backups 目录是否存在
if [ ! -d "/tmp/jenkins/backups" ]; then
    ERRLOG=$(mkdir -p "/tmp/jenkins/backups" 2>&1)
    if [ $? -ne 0 ]; then
        ERRTEMP=$(echo "错误：无法创建备份目录 /tmp/jenkins/backups。日志：${ERRLOG}" | base64 -w 0)
        echo $(printf "$RESULT" "-1" "$ERRTEMP" "0")
        exit 1
    fi
fi

if [ ! -d "/tmp/jenkins_tmp" ]; then
    ERRLOG=$(mkdir -p "/tmp/jenkins_tmp" 2>&1)
    if [ $? -ne 0 ]; then
        ERRTEMP=$(echo "错误：无法创建临时解压目录 /tmp/jenkins_tmp。日志：${ERRLOG}" | base64 -w 0)
        echo $(printf "$RESULT" "-1" "$ERRTEMP" "0")
        exit 1
    fi
fi

# 第二步：从SFTP下载压缩文件到本地/tmp/目录下
ERRLOG=$(curl -o /tmp/jenkins/${BACKUP_FILENAME} ${SFTP_BASE_URL_INNER}${JENKINS_FILE_DIR}/${BACKUP_FILENAME} 2>&1)
if [ $? -ne 0 ]; then
    ERRTEMP=$(echo "错误：下载备份文件${BACKUP_FILENAME}失败。日志：${ERRLOG}" | base64 -w 0)
    echo $(printf "$RESULT" "-1" "$ERRTEMP" "0")
    exit 1
fi

# 第三步：将/var/jenkins_home/目录压缩备份到/var/jenkins_home/backups/目录下，命名为 yyyyMMddHHmmss.back.tar
ERRLOG=$(tar --exclude='./plugins' -czf /tmp/jenkins/backups/$(date +"%Y%m%d%H%M%S").back.tgz -C /var/jenkins_home/ ./ 2>&1)
if [ $? -ne 0 ]; then
    ERRTEMP=$(echo "错误：压缩备份目录/var/jenkins_home/失败。日志：${ERRLOG}" | base64 -w 0)
    echo $(printf "$RESULT" "-1" "$ERRTEMP" "0")
    exit 1
fi

# 第四步：解压下载的文件并覆盖到/var/jenkins_home/目录
ERRLOG=$(tar -xzf /tmp/jenkins/${BACKUP_FILENAME} -C /tmp/jenkins_tmp/ 2>&1)
if [ $? -ne 0 ]; then
    ERRTEMP=$(echo "错误：解压备份文件失败。日志：${ERRLOG}" | base64 -w 0)
    echo $(printf "$RESULT" "-1" "$ERRTEMP" "0")
    exit 1
fi

ERRLOG=$(cp -rf /tmp/jenkins_tmp/* /var/jenkins_home 2>&1)
if [ $? -ne 0 ]; then
    ERRTEMP=$(echo "错误：将解压文件目录/tmp/jenkins_tmp/文件cp至/var/jenkins_home失败。日志：${ERRLOG}" | base64 -w 0)
    echo $(printf "$RESULT" "-1" "$ERRTEMP" "0")
    exit 1
fi

ERRLOG=$(rm -rf /tmp/jenkins_tmp/ 2>&1)
if [ $? -ne 0 ]; then
    ERRTEMP=$(echo "错误：无法删除临时文件目录/tmp/jenkins_tmp/。日志：${ERRLOG}" | base64 -w 0)
    echo $(printf "$RESULT" "-1" "$ERRTEMP" "0")
    exit 1
fi

# 删除下载的压缩文件
ERRLOG=$(rm -f /tmp/jenkins/${BACKUP_FILENAME} 2>&1)
if [ $? -ne 0 ]; then
    ERRTEMP=$(echo "警告：无法删除文件 /tmp/jenkins/${BACKUP_FILENAME}。日志：${ERRLOG}\n" | base64 -w 0)
fi

# 保证/var/jenkins_home/backups/目录下最多保留5份备份文件，删除时间最早的文件
BACKUP_COUNT=$(ls -1 /tmp/jenkins/backups/*.back.tgz 2>/dev/null | wc -l)
if [ $BACKUP_COUNT -gt 5 ]; then
    FILES_TO_DELETE=$(ls -1rt /tmp/jenkins/backups/*.back.tgz 2>/dev/null | head -n $(($BACKUP_COUNT - 5)))
    for file in $FILES_TO_DELETE; do
        ERRLOG=$(rm -f "$file" 2>&1)
        if [ $? -ne 0 ]; then
            ERRTEMP=$(echo "警告：无法删除文件 $file。日志：${ERRLOG}\n" | base64 -w 0)
        fi
    done
fi

# 重启jenkins
ERRLOG=$(curl -u admin:Powerjenkins@2024 -X POST http://127.0.0.1:8080/powerci/restart 2>&1)
if [ $? -ne 0 ]; then
    ERRTEMP=$(echo "错误重启jenkins服务失败，日志：${ERRLOG}" | base64 -w 0)
    echo $(printf "$RESULT" "-1" "$ERRTEMP" "0")
    exit 1
fi

echo $(printf "$RESULT" "0" "$ERRTEMP" "$FILE_SIZE")

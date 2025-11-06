#!/bin/bash

# 테스트 파일 생성 및 S3 업로드
BUCKET_NAME="test-aho-transfer-speed"
TEST_FILES=(
    "test-100mb.dat:100"
    "test-1gb.dat:1024"
    "test-10gb.dat:10240"
)

for file_spec in "${TEST_FILES[@]}"; do
    filename=$(echo $file_spec | cut -d: -f1)
    size_mb=$(echo $file_spec | cut -d: -f2)

    # 테스트 파일 생성
    dd if=/dev/urandom of=$filename bs=1M count=$size_mb

    # S3 업로드
    aws s3 cp $filename s3://$BUCKET_NAME/test-data/$filename

    echo "Created and uploaded $filename (${size_mb}MB)"
done

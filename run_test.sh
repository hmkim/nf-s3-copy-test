#!/bin/bash

# 1. 테스트 데이터 준비
if [ -f "test-100mb.dat" ] && [ -f "test-1gb.dat" ] && [ -f "test-10gb.dat" ]; then
    echo "테스트 데이터가 이미 존재합니다. 데이터 준비를 건너뜁니다."
else
    echo "Preparing test data..."
    ./prepare-test-data.sh
fi

# 2. 워크플로우 파일 압축
echo "Compressing workflow files..."
if [ -f workflow.zip ]; then
    read -p "workflow.zip 파일이 이미 존재합니다. 삭제하고 새로 생성하시겠습니까? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm workflow.zip
        echo "기존 파일을 삭제했습니다."
    else
        echo "기존 파일을 유지합니다. 압축을 건너뜁니다."
        exit 1
    fi
fi
zip -r workflow.zip performance-test.nf

# 3. HealthOmics 워크플로우 생성
echo "Creating HealthOmics workflow..."
WORKFLOW_ID=$(aws omics create-workflow \
    --name "file-transfer-performance-test" \
    --description "Compare Channel.fromPath vs s3 cp performance" \
    --engine NEXTFLOW \
    --definition-zip fileb://workflow.zip \
    --main performance-test.nf \
    --query 'id' --output text)

echo "Workflow created: $WORKFLOW_ID"

# 워크플로우 등록 완료 확인
echo "Waiting for workflow registration to complete..."
while true; do
    WORKFLOW_STATUS=$(aws omics get-workflow --id $WORKFLOW_ID --query 'status' --output text)
    echo "Workflow status: $WORKFLOW_STATUS"
    
    if [[ "$WORKFLOW_STATUS" == "ACTIVE" ]]; then
        echo "Workflow registration completed successfully"
        break
    elif [[ "$WORKFLOW_STATUS" == "FAILED" ]]; then
        echo "Workflow registration failed"
        exit 1
    fi
    
    sleep 10
done

# 4. 워크플로우 실행
echo "Starting workflow run..."
RUN_ID=$(aws omics start-run \
    --workflow-id $WORKFLOW_ID \
    --role-arn "arn:aws:iam::664263524008:role/OmicsUnifiedJobRole" \
    --parameters '{"bucket":"test-aho-transfer-speed","test_files":["test-100mb.dat","test-1gb.dat","test-10gb.dat"]}' \
    --output-uri "s3://test-aho-transfer-speed/results-aho/" \
    --query 'id' --output text)

echo "Run started: $RUN_ID"

# 5. 실행 상태 모니터링
echo "Monitoring run status..."
while true; do
    STATUS=$(aws omics get-run --id $RUN_ID --query 'status' --output text)
    echo "Status: $STATUS"

    if [[ "$STATUS" == "COMPLETED" ]]; then
        echo "Run completed successfully"
        break
    elif [[ "$STATUS" == "FAILED" ]]; then
        echo "Run failed"
        exit 1
    fi

    sleep 30
done

## 6. 결과 다운로드 및 분석
#echo "Downloading results..."
#aws s3 sync s3://your-test-bucket/results/ ./results/
#
#echo "Analyzing results..."
#python3 analyze_results.py
#
#echo "Sending metrics to CloudWatch..."
#./cloudwatch-metrics.sh

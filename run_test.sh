#!/bin/bash

# 1. 테스트 데이터 준비
echo "Preparing test data..."
./prepare-test-data.sh

# 2. 워크플로우 파일 압축
echo "Compressing workflow files..."
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

# 6. 결과 다운로드 및 분석
echo "Downloading results..."
aws s3 sync s3://your-test-bucket/results/ ./results/

echo "Analyzing results..."
python3 analyze_results.py

echo "Sending metrics to CloudWatch..."
./cloudwatch-metrics.sh

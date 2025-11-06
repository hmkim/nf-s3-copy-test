# AWS HealthOmics S3 파일 전송 성능 테스트

이 프로젝트는 AWS HealthOmics에서 Nextflow를 사용할 때 S3 파일 전송 방법에 따른 성능 차이를 비교 분석하는 도구입니다.

## 📋 프로젝트 개요

AWS HealthOmics 환경에서 두 가지 S3 파일 접근 방법의 성능을 비교합니다:
- **Channel.fromPath**: Nextflow의 내장 S3 파일 접근 방식 (자동 다운로드)
- **aws s3 cp**: AWS CLI를 사용한 명시적 파일 다운로드

## 🗂️ 파일 구조

```
├── performance-test.nf      # Nextflow 워크플로우 (성능 테스트 로직)
├── prepare-test-data.sh     # 테스트 데이터 생성 및 S3 업로드 스크립트
├── run_test.sh             # 전체 테스트 실행 스크립트 (자동화)
└── README.md               # 프로젝트 설명서
```

## 🚀 사용 방법

### 1. 원클릭 테스트 실행 (권장)
```bash
chmod +x run_test.sh
./run_test.sh
```

**자동 실행 과정:**
1. 테스트 데이터 존재 여부 확인 (있으면 건너뛰기)
2. 기존 workflow.zip 파일 확인 및 사용자 선택
3. HealthOmics 워크플로우 생성 및 등록 완료 대기
4. 워크플로우 실행 및 상태 모니터링
5. 결과 다운로드 및 분석

### 2. 개별 단계 실행

#### 테스트 데이터 준비
```bash
chmod +x prepare-test-data.sh
./prepare-test-data.sh
```
- **생성 파일**: 100MB, 1GB, 10GB 크기의 랜덤 데이터
- **업로드 위치**: `s3://test-aho-transfer-speed/test-data/`
- **파일명**: `test-100mb.dat`, `test-1gb.dat`, `test-10gb.dat`

#### 로컬 Nextflow 테스트 (개발용)
```bash
nextflow run performance-test.nf
```

## 📊 테스트 상세 내용

### 테스트 시나리오
각 파일 크기별로 두 가지 방법을 **병렬로** 테스트:

| 파일 크기 | Channel.fromPath | AWS S3 CP |
|-----------|------------------|-----------|
| 100MB     | ✅ 자동 다운로드    | ✅ 명시적 다운로드 |
| 1GB       | ✅ 자동 다운로드    | ✅ 명시적 다운로드 |
| 10GB      | ✅ 자동 다운로드    | ✅ 명시적 다운로드 |

### 성능 측정 방식
```bash
# 각 프로세스에서 실행되는 측정 로직
start_time=$(date +%s.%N)
# 파일 전송/처리
end_time=$(date +%s.%N)
throughput=$(계산된 MB/s)
```

### 출력 예시
```
Channel.fromPath - test-100mb.dat: 45.67 MB/s
S3 CP - test-100mb.dat: 38.92 MB/s
Channel.fromPath - test-1gb.dat: 52.34 MB/s
S3 CP - test-1gb.dat: 41.28 MB/s
```

## 🔧 설정 요구사항

### 필수 AWS 권한
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::test-aho-transfer-speed",
        "arn:aws:s3:::test-aho-transfer-speed/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "omics:CreateWorkflow",
        "omics:StartRun",
        "omics:GetWorkflow",
        "omics:GetRun"
      ],
      "Resource": "*"
    }
  ]
}
```

### 환경 설정
- **AWS CLI**: 구성 완료 (`aws configure`)
- **Nextflow**: 22.04.0 이상 권장
- **IAM 역할**: `arn:aws:iam::664263524008:role/OmicsUnifiedJobRole`
- **S3 버킷**: `test-aho-transfer-speed` (자동 생성됨)

### 실행 전 확인사항
```bash
# AWS CLI 설정 확인
aws sts get-caller-identity

# S3 접근 권한 확인
aws s3 ls s3://test-aho-transfer-speed/

# HealthOmics 서비스 가용성 확인
aws omics list-workflows --max-items 1
```

## 📈 결과 분석 및 해석

### 예상 결과 패턴
1. **소용량 파일 (100MB)**: S3 CP가 더 빠를 수 있음 (오버헤드 적음)
2. **대용량 파일 (1GB+)**: Channel.fromPath가 더 효율적 (최적화된 전송)
3. **네트워크 상황**: 결과에 영향을 미치는 주요 변수

### 성능 최적화 권장사항
- **소용량 파일**: AWS S3 CP 사용 고려
- **대용량 파일**: Channel.fromPath 사용 권장
- **배치 처리**: 파일 크기에 따른 적응적 전략 적용

## 🔍 트러블슈팅

### 일반적인 문제
1. **권한 오류**: IAM 역할 및 정책 확인
2. **네트워크 타임아웃**: 대용량 파일 처리 시 시간 증가 정상
3. **워크플로우 등록 실패**: workflow.zip 파일 크기 및 형식 확인

### 디버깅 명령어
```bash
# 워크플로우 상태 확인
aws omics get-workflow --id <WORKFLOW_ID>

# 실행 로그 확인
aws omics get-run --id <RUN_ID>

# S3 파일 확인
aws s3 ls s3://test-aho-transfer-speed/test-data/ --human-readable
```

## 🎯 활용 목적 및 확장성

### 즉시 활용
- HealthOmics 워크플로우 최적화
- 대용량 파일 처리 성능 개선
- S3 전송 방식 선택 가이드라인 제공

### 확장 가능성
- 다양한 파일 크기 테스트 추가
- 멀티파트 업로드 성능 비교
- 리전 간 전송 성능 측정
- CloudWatch 메트릭 자동 수집 및 대시보드 구성

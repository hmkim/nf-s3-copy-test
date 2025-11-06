#!/usr/bin/env nextflow

params.bucket = "test-aho-transfer-speed"
params.test_files = ["test-100mb.dat", "test-1gb.dat", "test-10gb.dat"]

// Method 1: Nextflow 자동 staging (Channel.fromPath)
process testChannelFromPath {
    input:
    path input_file

    script:
    """
    start_time=\$(date +%s.%N)
    
    # 파일이 이미 Nextflow에 의해 자동으로 staged됨
    # 단순히 파일 크기 확인 및 복사로 처리 시뮬레이션
    #cp ${input_file} ./processed_\$(basename ${input_file})
    
    end_time=\$(date +%s.%N)
    duration=\$(echo "\$end_time \$start_time" | awk '{printf "%.6f", \$1 - \$2}')
    file_size=\$(stat -c%s ${input_file})
    throughput=\$(echo "\$file_size \$duration" | awk '{printf "%.2f", \$1 / \$2 / 1024 / 1024}')
    
    echo "Nextflow Staging - \$(basename ${input_file}): \${throughput} MB/s (File size: \${file_size} bytes, staging time included by Nextflow)"
    """
}

// Method 2: 명시적 S3 다운로드
process testS3Cp {
    input:
    val filename

    script:
    """
    start_time=\$(date +%s.%N)
    
    # 사용자가 명시적으로 S3에서 다운로드
    aws s3 cp s3://${params.bucket}/test-data/${filename} ./downloaded_${filename}
    
    end_time=\$(date +%s.%N)
    duration=\$(echo "\$end_time \$start_time" | awk '{printf "%.6f", \$1 - \$2}')
    file_size=\$(stat -c%s ./downloaded_${filename})
    throughput=\$(echo "\$file_size \$duration" | awk '{printf "%.2f", \$1 / \$2 / 1024 / 1024}')
    
    echo "Explicit S3 CP - ${filename}: \${throughput} MB/s (File size: \${file_size} bytes)"
    """
}

workflow {
    // Method 1: Nextflow의 자동 staging 사용 (glob 패턴)
    staged_files = Channel.fromPath("s3://${params.bucket}/test-data/test-*.dat")
    staged_files.view { "Staged file: $it" }
    testChannelFromPath(staged_files)
    
    // Method 2: 명시적 다운로드
    testS3Cp(Channel.from(params.test_files))
}

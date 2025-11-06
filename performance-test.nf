#!/usr/bin/env nextflow

params.bucket = "test-aho-transfer-speed"
params.test_files = ["test-100mb.dat", "test-1gb.dat", "test-10gb.dat"]

// Method 1: Channel.fromPath
process testChannelFromPath {
    input:
    path input_file

    script:
    """
    start_time=\$(date +%s.%N)
    
    # 파일이 이미 로컬에 다운로드됨 (Channel.fromPath에 의해)
    cp ${input_file} ./downloaded_\$(basename ${input_file})
    
    end_time=\$(date +%s.%N)
    duration=\$(echo "\$end_time \$start_time" | awk '{printf "%.6f", \$1 - \$2}')
    file_size=\$(stat -c%s ${input_file})
    throughput=\$(echo "\$file_size \$duration" | awk '{printf "%.2f", \$1 / \$2 / 1024 / 1024}')
    
    echo "Channel.fromPath - \$(basename ${input_file}): \${throughput} MB/s"
    """
}

// Method 2: Explicit s3 cp
process testS3Cp {
    input:
    val filename

    script:
    """
    start_time=\$(date +%s.%N)
    
    aws s3 cp s3://${params.bucket}/test-data/${filename} ./downloaded_${filename} 
    
    end_time=\$(date +%s.%N)
    duration=\$(echo "\$end_time \$start_time" | awk '{printf "%.6f", \$1 - \$2}')
    file_size=\$(stat -c%s downloaded_${filename})
    throughput=\$(echo "\$file_size \$duration" | awk '{printf "%.2f", \$1 / \$2 / 1024 / 1024}')
    
    echo "S3 CP - ${filename}: \${throughput} MB/s"
    """
}

workflow {
    // Channel.fromPath 테스트 - S3에서 직접 파일 읽기
    channel_files = Channel.fromPath("s3://${params.bucket}/test-data/{${params.test_files.join(',')}}")
    testChannelFromPath(channel_files)
    
    // s3 cp 테스트
    testS3Cp(Channel.from(params.test_files))
}

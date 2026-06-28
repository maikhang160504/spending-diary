# 1. Chạy pipeline dự đoán trên tập private test qua SSH
Write-Host "Đang chạy dự đoán Private Test trên Cloud Server..."
ssh -p 20111 root@hn1.forai.cloud "docker exec -e MC_OCR_DATASET=mc_ocr_private_test -w /workspace/mc_ocr 4cb839626232 bash run_all.sh"

# 2. Sau khi dự đoán xong, tự động tải file results.csv về máy local để nộp bài
Write-Host "Đang tải file results.csv về thư mục riêng biệt tại máy local..."
New-Item -ItemType Directory -Force -Path "d:\Luan-Van\Project\MC_OCR\downloaded_results\"
scp -P 20111 root@hn1.forai.cloud:/workspace/MC_OCR/mc_ocr/submit/mc_ocr_private_test/results.csv "d:\Luan-Van\Project\MC_OCR\downloaded_results\results.csv"
Write-Host "Tải file kết quả thành công! File lưu tại: d:\Luan-Van\Project\MC_OCR\downloaded_results\results.csv"

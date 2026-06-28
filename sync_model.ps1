# 1. Chạy lệnh train trên Server qua SSH và đợi hoàn thành
Write-Host "Đang bắt đầu train model trên Cloud Server..."
ssh -p 20111 root@hn1.forai.cloud "docker exec -w /workspace/mc_ocr/key_info_extraction/PICK 4cb839626232 bash run.sh"

# 2. Sau khi train xong, tự động tìm và tải file model_best.pth mới nhất về máy local
Write-Host "Đã train xong! Đang tìm kiếm model mới nhất trên server..."
ssh -p 20111 root@hn1.forai.cloud "ln -sf \$(find /workspace/MC_OCR/mc_ocr/key_info_extraction/PICK/saved/models/PICK_Default/ -name 'model_best.pth' -type f | sort | tail -n 1) /workspace/MC_OCR/mc_ocr/key_info_extraction/PICK/saved/models/PICK_Default/latest_model_best.pth"

# Tải file weights mới nhất về local
New-Item -ItemType Directory -Force -Path "d:\Luan-Van\Project\MC_OCR\downloaded_models\"
scp -P 20111 root@hn1.forai.cloud:/workspace/MC_OCR/mc_ocr/key_info_extraction/PICK/saved/models/PICK_Default/latest_model_best.pth "d:\Luan-Van\Project\MC_OCR\downloaded_models\model_best.pth"
Write-Host "Tải file thành công! File lưu tại: d:\Luan-Van\Project\MC_OCR\downloaded_models\model_best.pth"

# 3. Tải toàn bộ log và TensorBoard về máy local để theo dõi
Write-Host "Tiến hành tải toàn bộ log và TensorBoard events..."
New-Item -ItemType Directory -Force -Path "d:\Luan-Van\Project\MC_OCR\downloaded_logs\"
scp -P 20111 -r root@hn1.forai.cloud:/workspace/MC_OCR/mc_ocr/key_info_extraction/PICK/saved/log/ "d:\Luan-Van\Project\MC_OCR\downloaded_logs\"
Write-Host "Tải log thành công! Lưu tại: d:\Luan-Van\Project\MC_OCR\downloaded_logs\"

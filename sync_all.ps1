# ==========================================
# PIPELINE TỰ ĐỘNG HÓA HOÀN TOÀN (TRAIN -> INFERENCE -> DOWNLOAD)
# ==========================================

# BƯỚC 1: CHẠY HUẤN LUYỆN (TRAIN) MÔ HÌNH PICK
Write-Host "==========================================" -ForegroundColor Green
Write-Host "BƯỚC 1: Đang khởi chạy huấn luyện trên Cloud Server..." -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
ssh -p 20111 root@hn1.forai.cloud "docker exec -w /workspace/mc_ocr/key_info_extraction/PICK 4cb839626232 bash run.sh"

# BƯỚC 2: TẢI FILE WEIGHTS MODEL VỀ MÁY LOCAL
Write-Host "`n==========================================" -ForegroundColor Green
Write-Host "BƯỚC 2: Đã train xong! Đang tìm kiếm model mới nhất trên server..." -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
# Tạo liên kết động tới file model_best.pth mới nhất trên server
ssh -p 20111 root@hn1.forai.cloud "ln -sf \$(find /workspace/MC_OCR/mc_ocr/key_info_extraction/PICK/saved/models/PICK_Default/ -name 'model_best.pth' -type f | sort | tail -n 1) /workspace/MC_OCR/mc_ocr/key_info_extraction/PICK/saved/models/PICK_Default/latest_model_best.pth"

# Tải file weights mới nhất về local
New-Item -ItemType Directory -Force -Path "d:\Luan-Van\Project\MC_OCR\downloaded_models\"
scp -P 20111 root@hn1.forai.cloud:/workspace/MC_OCR/mc_ocr/key_info_extraction/PICK/saved/models/PICK_Default/latest_model_best.pth "d:\Luan-Van\Project\MC_OCR\downloaded_models\model_best.pth"
Write-Host "Tải file model mới nhất thành công!" -ForegroundColor Cyan

# BƯỚC 2.5: TẢI TOÀN BỘ LOG & TENSORBOARD VỀ MÁY LOCAL
Write-Host "`n==========================================" -ForegroundColor Green
Write-Host "Tải toàn bộ log và TensorBoard events về máy local..." -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
New-Item -ItemType Directory -Force -Path "d:\Luan-Van\Project\MC_OCR\downloaded_logs\"
scp -P 20111 -r root@hn1.forai.cloud:/workspace/MC_OCR/mc_ocr/key_info_extraction/PICK/saved/log/ "d:\Luan-Van\Project\MC_OCR\downloaded_logs\"
Write-Host "Tải log thành công! Lưu tại: d:\Luan-Van\Project\MC_OCR\downloaded_logs\" -ForegroundColor Cyan

# BƯỚC 3: CHẠY DỰ ĐOÁN (INFERENCE) TRÊN TẬP PRIVATE TEST
Write-Host "`n==========================================" -ForegroundColor Green
Write-Host "BƯỚC 3: Bắt đầu chạy dự đoán Private Test trên Cloud Server..." -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
ssh -p 20111 root@hn1.forai.cloud "docker exec -e MC_OCR_DATASET=mc_ocr_private_test -w /workspace/mc_ocr 4cb839626232 bash run_all.sh"

# BƯỚC 4: TẢI FILE KẾT QUẢ SUBMISSION (RESULTS.CSV) VỀ LOCAL
Write-Host "`n==========================================" -ForegroundColor Green
Write-Host "BƯỚC 4: Dự đoán xong! Tiến hành tải file submission results.csv..." -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
New-Item -ItemType Directory -Force -Path "d:\Luan-Van\Project\MC_OCR\downloaded_results\"
scp -P 20111 root@hn1.forai.cloud:/workspace/MC_OCR/mc_ocr/submit/mc_ocr_private_test/results.csv "d:\Luan-Van\Project\MC_OCR\downloaded_results\results.csv"
Write-Host "Hoàn thành toàn bộ pipeline! File lưu tại: d:\Luan-Van\Project\MC_OCR\downloaded_results\results.csv" -ForegroundColor Yellow

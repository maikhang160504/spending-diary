2. hãy retrain lại text nlu và test lại các phần cần thiết bằng expense-ocr-nlu\text_nlu\tools và expense-ocr-nlu\tests  
sau đó đưa ra phân tích  
4. kiểm tra tính retrain có hệ thống nhận dạng text-nlu khi có thay đổi category đã nhận dạng, và cá nhân hóa nhãn dán từng người dùng. kiểm tra webadmin đã có tính năng này chưa, nếu có hãy phân tích xem tính năng này đã đầy đủ, nếu còn chưa hoàn thiện hãy hoàn thiện nó
5. train LayoutLMv3 với pie-data bằng kaggle notebook bằng tập dữ liệu expense-ocr-nlu\OCR\kaggle\input\datasets\domixi1989\vietnamese-receipts-mc-ocr-2021\kie_data dựa vào notebook expense-ocr-nlu\OCR\kaggle\vietnamese_receipts_mc_ocr_train.ipynb
6. xử lí vấn đề đang có về các lỗi ocr bill: nghiêng xoắn, mất chữ, nhận dạng sai 
7. phân loại cho hóa đơn bằng mô hình record sẳn có, bỏ qua rule dựa vào địa điểm, địa chỉ,brand, sản phẩm,... 
8. xây dựng retrain ocr trên webadmin bằng kaggle pipeline bằng cách gán nhãn tự động và thủ công ( cho mô hình LayoutLMv3 và paddle+vietocr)
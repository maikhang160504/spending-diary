import joblib
import os
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.svm import SVC
from sklearn.pipeline import make_pipeline

# 1. Dữ liệu huấn luyện
data = [
    ("ăn phở", "Ăn uống"), ("uống cà phê", "Ăn uống"), ("cơm tiệm", "Ăn uống"), ("trà sữa chân châu", "Ăn uống"),
    ("đổ xăng xe", "Di chuyển"), ("tiền grab đi học", "Di chuyển"), ("vé xe bus", "Di chuyển"), ("sửa xe máy", "Di chuyển"),
    ("mua quần áo", "Mua sắm"), ("đi siêu thị", "Mua sắm"), ("mua đồ dùng", "Mua sắm"), ("shopee chốt đơn", "Mua sắm"),
    ("tiền điện tháng 5", "Hóa đơn"), ("đóng tiền nước", "Hóa đơn"), ("cước wifi", "Hóa đơn"), ("internet", "Hóa đơn"),
    ("mua thuốc cảm", "Sức khỏe"), ("đi khám răng", "Sức khỏe"), ("mua khẩu trang", "Sức khỏe"), ("vitamin c", "Sức khỏe")
]

texts, labels = zip(*data)

# 2. Xây dựng Pipeline: TF-IDF + SVM
# Chúng ta dùng ngram_range=(1, 2) để máy hiểu được cả từ đơn và từ ghép
model = make_pipeline(
    TfidfVectorizer(ngram_range=(1, 2)), 
    SVC(kernel='linear', probability=True)
)

# 3. Huấn luyện
model.fit(texts, labels)

# 4. Đóng gói (Export)
output_dir = os.path.join(os.path.dirname(__file__), '..', 'core')
os.makedirs(output_dir, exist_ok=True)
model_path = os.path.join(output_dir, "expense_classifier.pkl")
joblib.dump(model, model_path)
print(f"✅ Đã xuất file mô hình tại: {model_path} thành công!")

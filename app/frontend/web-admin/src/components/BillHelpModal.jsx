import { useEffect } from "react";

function HelpIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="1.5" />
      <path d="M12 11v5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
      <circle cx="12" cy="8" r="0.75" fill="currentColor" />
    </svg>
  );
}

export function BillHelpTrigger({ onClick }) {
  return (
    <button type="button" className="bill-help-trigger" onClick={onClick} aria-haspopup="dialog">
      <HelpIcon />
      <span>Hướng dẫn</span>
    </button>
  );
}

export default function BillHelpModal({ open, onClose }) {
  useEffect(() => {
    if (!open) return undefined;
    const onKey = (e) => {
      if (e.key === "Escape") onClose();
    };
    document.body.style.overflow = "hidden";
    window.addEventListener("keydown", onKey);
    return () => {
      document.body.style.overflow = "";
      window.removeEventListener("keydown", onKey);
    };
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div className="bill-modal-root" role="presentation">
      <button type="button" className="bill-modal-backdrop" aria-label="Đóng hướng dẫn" onClick={onClose} />
      <div className="bill-modal" role="dialog" aria-modal="true" aria-labelledby="bill-help-title">
        <header className="bill-modal-header">
          <div>
            <p className="bill-modal-eyebrow">Bill OCR Retrain</p>
            <h2 id="bill-help-title" className="bill-modal-title">Hướng dẫn sử dụng</h2>
          </div>
          <button type="button" className="bill-modal-close" onClick={onClose} aria-label="Đóng">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
              <path d="M6 6l12 12M18 6L6 18" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
            </svg>
          </button>
        </header>

        <div className="bill-modal-body">
          <section className="bill-help-section">
            <h3>Quy trình gợi ý</h3>
            <ol className="bill-help-flow">
              <li>
                <span className="bill-help-step-num">1</span>
                <div>
                  <strong>Upload ảnh</strong>
                  <p>Thêm hóa đơn vào hàng đợi — chưa chạy model.</p>
                </div>
              </li>
              <li>
                <span className="bill-help-step-num">2</span>
                <div>
                  <strong>Gán nhãn auto</strong>
                  <p>PaddleOCR + VietOCR + LayoutLMv3 — hoặc chỉnh tay: kéo bbox, <strong>Thêm bbox</strong> vẽ vùng mới, sửa text/entity, Xóa nhãn.</p>
                </div>
              </li>
              <li>
                <span className="bill-help-step-num">3</span>
                <div>
                  <strong>Lưu nháp / Duyệt</strong>
                  <p>Lưu nháp giữ chỉnh sửa tay; Duyệt để đưa vào export train.</p>
                </div>
              </li>
              <li>
                <span className="bill-help-step-num">4</span>
                <div>
                  <strong>Export &amp; Kaggle</strong>
                  <p>Xuất PICK TSV + VietOCR crops. Bật Auto Kaggle để train ngay sau export.</p>
                </div>
              </li>
              <li>
                <span className="bill-help-step-num">5</span>
                <div>
                  <strong>Theo dõi tiến độ</strong>
                  <p>Khi retrain xong, weights deploy và ai-service reload OCR tự động.</p>
                </div>
              </li>
            </ol>
          </section>

          <section className="bill-help-section">
            <h3>Chức năng các nút</h3>
            <div className="bill-help-grid">
              <div className="bill-help-card">
                <strong>Upload ảnh</strong>
                <p>Chỉ lưu ảnh vào hàng đợi.</p>
              </div>
              <div className="bill-help-card">
                <strong>Gán nhãn auto</strong>
                <p>Chạy hybrid pipeline trên ảnh đang chọn.</p>
              </div>
              <div className="bill-help-card">
                <strong>Duyệt nhãn</strong>
                <p>Đánh dấu sample sẵn sàng export.</p>
              </div>
              <div className="bill-help-card">
                <strong>Xóa nhãn</strong>
                <p>Xóa bbox đang chọn (nút hoặc phím Delete).</p>
              </div>
              <div className="bill-help-card">
                <strong>Lưu nháp</strong>
                <p>Lưu adminLabels chưa duyệt.</p>
              </div>
              <div className="bill-help-card">
                <strong>Export approved</strong>
                <p>Đóng gói nhãn cho kernel LayoutLMv3 / VietOCR.</p>
              </div>
              <div className="bill-help-card">
                <strong>Tải lại model OCR</strong>
                <p>Reload weights sau deploy hoặc lazy load lần đầu.</p>
              </div>
            </div>
          </section>

          <section className="bill-help-section bill-help-section-note">
            <h3>Kaggle accuracy cao nhưng production sai?</h3>
            <ul className="bill-help-notes">
              <li>Kaggle eval = token-level trên PICK TSV; production = detect → read → KIE trên ảnh mới.</li>
              <li>Lệch preprocessing: word/bbox alignment, resize giữa train và infer.</li>
              <li>Bbox PaddleOCR ở production khác distribution MC-OCR train set.</li>
              <li>Sau retrain: bấm <strong>Tải lại model OCR</strong> hoặc đợi webhook reload.</li>
            </ul>
          </section>
        </div>

        <footer className="bill-modal-footer">
          <button type="button" className="btn btn-primary" onClick={onClose}>
            Đã hiểu
          </button>
        </footer>
      </div>
    </div>
  );
}

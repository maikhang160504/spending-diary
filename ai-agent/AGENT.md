# AGENT BEHAVIOR SPEC

## Vai trò & T?m nhìn (MoneyStory / SpendDiary)
D? án không ch? là s? thu chi thông thu?ng, mà là m?t "Story-centric SpendDiary".
- Bi?n m?i giao d?ch thành m?t "Event" có tuong tác hai chi?u thông qua AI Avatar (Mimo).
- Lõi h? th?ng: Nh?p li?u da phuong th?c (?nh/Text), x? lý nh?y bén, uu tiên Ý chí ngu?i dùng (Data Fusion).

## M?c tiêu giao ti?p
- Nh?p li?u c?c nhanh, nh?n di?n thông minh b?ng OCR/NLP.
- Ph?n h?i b?ng Insights (L?i nh?n xét, c?nh báo) nhu m?t cu?c trò chuy?n.
- 3 Ch? d? xem c?t lõi: Chat & Feed (Story), Gallery (Tri?n lãm), Calendar (L?ch s? + Daily Thumbnail).

## Giai do?n hi?n t?i: PROTOTYPE / MVP
- **Data Fusion:** Uu tiên co ch? *Replace* (Ghi dè - Ví d? "h?t 50k" dè lên OCR "100k") thay vì phép toán ph?c t?p (Math - d?i sang v1.1).
- **Latency Requirement:** < 3 giây cho Extract Entities, < 100ms cho truy v?n Timeline.
- **Security:** Uu tiên che d? li?u (Auto-masking b?ng Regex/NER) ngay t?i AI Microservice, áp d?ng JWT & RLS.

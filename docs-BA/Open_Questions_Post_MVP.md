# Open Questions — Post-MVP

Các nội dung dưới đây **không phải blocker để triển khai Operational MVP FR-01–FR-20**, trừ khi Product Owner thay đổi scope. Không tự triển khai chỉ dựa trên tài liệu này.

## Tích hợp và trải nghiệm ngoài MVP

1. Có tích hợp QBO không? Nếu có: Invoice hay SalesReceipt, Customer map theo Student hay Parent, Item/Account mapping và cơ chế retry/idempotency.
2. SePay là Speaker API hay đối soát VA/ngân hàng? Hai bài toán này không được coi là một.
3. Có cần SMS/Zalo/email automation cho payment, vắng học hoặc lịch học không? Template, consent, retry và chi phí do ai duyệt?
4. Có xây portal/mobile cho Student/Parent không? Phạm vi dữ liệu, reset password và privacy policy thế nào?
5. Có cần QR/payment gateway hoặc VAT e-invoice không? Đây là scope tài chính/pháp lý riêng.

## Tài chính và vận hành nâng cao

6. Quy chế kế toán chính thức cho receipt, refund, adjustment, retention và numbering sau MVP là gì?
7. Có cần ledger kế toán đầy đủ, export kế toán, reconciliation ngân hàng hoặc nhiều loại tiền không?
8. Có hỗ trợ nhiều bảng giá/khuyến mại cộng dồn sau MVP không?
9. Có cần payroll/back-office đầy đủ ngoài teacher-hours theo session không?

## Học thuật và báo cáo nâng cao

10. Có thêm quiz, speaking, writing, rubric hoặc điểm ngoài MIDTERM/FINAL không?
11. Có cần ngưỡng điểm thấp configurable, report card và feedback cho phụ huynh không?
12. Có cần Syllabus versioning, kho tài liệu, lesson resources hoặc cập nhật syllabus runtime không?
13. Có cần dashboard doanh thu/KPI, forecast, conversion funnel hoặc báo cáo nâng cao không?

## Notification, policy và scale

14. Quy định retention/xóa dữ liệu PII, quyền export và yêu cầu audit compliance chính thức là gì?
15. Chính sách idle timeout, password rotation, MFA/SSO và lockout sau đăng nhập sai cần mức nào?
16. SLA/performance chính thức cho 10.000 học viên, report/export lớn và backup/restore là gì?
17. Có cần timezone/holiday calendar theo từng branch và lịch nghỉ bù không?

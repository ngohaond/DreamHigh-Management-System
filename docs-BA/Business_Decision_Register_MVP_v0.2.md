# Business Decision Register — DreamHigh MVP

**Phiên bản:** 0.2 — Approved Baseline  
**Ngày chốt:** 19/10/2026  
**Phạm vi:** FR-01–FR-20 của Operational MVP  
**Nguồn:** `PRD_QuanLyDaoTao_TrungTamTiengAnh.md`, SRS Module 01/02, ERD và các quyết định được xác nhận trong phiên làm việc.

> Đây là baseline sản phẩm để dev triển khai MVP. Nó không thay thế quy chế kế toán, thuế, pháp lý hoặc phê duyệt vận hành chính thức. Các mục ngoài phần này nằm ở `Open_Questions_Post_MVP.md`.

## 1. Scope và out-of-scope

### In scope

- Đủ FR-01–FR-20 cho Go-Live nội bộ.
- Quản lý catalog, course, Syllabus, class, session, enrollment.
- Lịch học, conflict detection, dời lịch, đổi giáo viên/phòng.
- Attendance, absence alert, exam/grade/feedback.
- Học phí, discount, invoice, payment, adjustment/refund, receipt PDF.
- Báo cáo công nợ và invoice quá hạn.
- RBAC, branch isolation, audit và dữ liệu tồn tại sau reload.

### Out of scope cho MVP

- QBO, SePay, SMS/Zalo automation.
- Portal học viên/phụ huynh, mobile app.
- Payment gateway, QR payment và hóa đơn VAT điện tử.
- Dashboard doanh thu/KPI nâng cao.
- Chat nội bộ và AI analytics.

## 2. IAM, RBAC và branch policy

### Vai trò

| Role | Phạm vi dữ liệu | Quyền tổng quát |
|---|---|---|
| `ADMIN` | Cross-branch | Cấu hình hệ thống, user/role/branch, toàn bộ nghiệp vụ và báo cáo |
| `MANAGER` | Branch được cấp | Quản lý nghiệp vụ trong branch; mở khóa attendance/grade theo quy định |
| `STAFF` | Branch được cấp | Học vụ, student/enrollment, attendance; ghi payment thường |
| `TEACHER` | Branch/lớp/session được phân công | Xem lớp được giao, nhập attendance và grade trước khi khóa |

- Không tạo role `DIRECTOR` trong MVP; quyền BGĐ được cấp bằng `ADMIN`.
- Backend suy ra scope từ JWT/user policy. `branchId` từ client chỉ là filter được kiểm tra, không phải quyền.
- User branch A không được đọc, tạo, sửa hoặc xóa dữ liệu branch B nếu không có quyền cross-branch.
- Teacher chỉ thao tác lớp/session được phân công, dù có thể thuộc nhiều branch.
- `MANAGER` và `STAFF` được mở khóa attendance; `MANAGER` và `ADMIN` được mở khóa grade.
- Mọi thao tác mở khóa cần lý do, actor, thời điểm và audit.

### Ownership bắt buộc

- `Lead`, `Student`, `Class`, `Session`, `Invoice`, `Payment` và báo cáo tài chính phải truy ra được branch owner.
- Student/Lead có một branch cố định trong MVP.
- Chuyển branch chỉ do `ADMIN`; branch đích phải tồn tại và `ACTIVE`; bắt buộc lý do và audit.
- Không cho phép tạo liên kết cross-branch không hợp lệ giữa student/class/invoice/payment.

## 3. Duplicate và lifecycle học viên

### Duplicate

- Chuẩn hóa số điện thoại trước khi so sánh.
- Khi nghi trùng Lead/Student/Parent, API trả cảnh báo cùng các bản ghi liên quan; không tự merge.
- `MANAGER` hoặc `ADMIN` có thể xác nhận tiếp tục tạo; bắt buộc lý do; lưu warning, bản ghi liên quan, actor và lý do vào audit.
- Không xóa bản ghi cũ tự động.

### Student lifecycle

```text
ACTIVE ↔ RESERVED
ACTIVE → DROPPED
ACTIVE → GRADUATED
RESERVED → ACTIVE
```

- Cấm `RESERVED → GRADUATED` trực tiếp.
- Chuyển trạng thái cần lý do và ghi `StudentStatusHistory` trong cùng transaction với update.
- Chuyển `RESERVED`/`DROPPED` không tự xóa enrollment, hủy invoice, hoàn payment hoặc xóa công nợ.
- Chuyển Lead → Student phải lưu liên kết nguồn và audit.

## 4. Course, Syllabus, Class và Session

### Course

Giữ lifecycle theo SRS/UI hiện có:

```text
KHỞI TẠO → ĐANG MỞ → ĐANG HỌC → HOÀN THÀNH
                                  ↘ NGỪNG
```

- Syllabus bắt buộc trước khi Course chuyển sang `ĐANG HỌC`.
- Course được coi là bắt đầu khi session đầu tiên của course chuyển `COMPLETED` hoặc attendance của session đầu tiên được khóa, tùy sự kiện nào xảy ra trước.
- Sau khi bắt đầu, không đổi level/Syllabus.
- Syllabus gốc không bị sửa bởi dữ liệu runtime của Course.

### Class và enrollment

- Class dùng các enum backend hiện có: `PLANNED`, `ACTIVE`, `COMPLETED`, `CANCELLED`; cần migration nếu muốn thêm trạng thái chưa có.
- Tạo class phải kiểm tra course/branch/teacher/room hợp lệ.
- Không vượt `maxStudents`.
- Không ghi danh cùng một student vào cùng class quá một lần.
- Conflict dùng khoảng thời gian chuẩn: `newStart < existingEnd && newEnd > existingStart`.
- Từ chối conflict của cùng teacher hoặc cùng room trong cùng branch/khung giờ, trả thông tin lớp/session xung đột.
- Chuyển lớp cần source class, target class, lý do, ngày hiệu lực, actor và audit.

### Session

- Tạo class và sinh session phải nằm trong transaction.
- Dời lịch/đổi giáo viên/đổi phòng phải chạy lại conflict check.
- Không dời hoặc đổi session đã hoàn thành hoặc đã khóa attendance.
- Session hủy không tính giờ dạy và không nhận attendance hợp lệ.
- Rescheduled chỉ được tính một lần trong báo cáo giờ dạy.

## 5. Attendance

- Enum: `PRESENT`, `ABSENT_EXCUSED`, `ABSENT_UNEXCUSED`.
- Mỗi cặp `(sessionId, studentId)` chỉ có một record.
- Chỉ student đang thuộc class/session mới được điểm danh.
- Teacher được tạo/sửa attendance trong **48 giờ sau `endTime`**, hoặc đến khi session bị khóa nếu khóa sớm hơn.
- Manager/Staff có thể mở khóa với lý do và audit.
- Cảnh báo khi có ít nhất **2 session liên tiếp `ABSENT_UNEXCUSED`**; `ABSENT_EXCUSED` ngắt chuỗi.
- Session `CANCELLED` không cho ghi attendance.

## 6. Exam, Grade và feedback

- MVP chỉ có hai loại exam: `MIDTERM` và `FINAL`.
- Mỗi class tối đa một exam mỗi loại.
- Score là số trong `0..100`; remarks là text có giới hạn độ dài API.
- Tổng `weightPercent` của các exam trong class không vượt 100%.
- Teacher phụ trách class nhập grade trước khi exam khóa.
- Manager/Admin mở khóa grade với lý do và audit.
- Thay đổi grade phải lưu before/after, actor, thời điểm và lý do nếu grade đã từng được lưu.
- MVP chưa tự động cảnh báo điểm thấp.

## 7. Teacher hours

- Kỳ báo cáo là tháng lịch, từ ngày 1 đến ngày cuối tháng.
- Chỉ session `COMPLETED` được tính; `CANCELLED` không tính.
- Session rescheduled chỉ tính một lần theo phiên hoàn thành cuối.
- Teacher thay phải lưu teacher thực tế; ngoại lệ cần Manager duyệt.
- Manager chốt kỳ giờ dạy; Admin mở lại với lý do và audit.
- Session thiếu trạng thái hoặc thời lượng hợp lệ bị loại khỏi tổng hợp và xuất hiện trong danh sách dữ liệu cần xử lý.

## 8. Finance

### Tiền và discount

- Đơn vị là VND nguyên; không dùng phần thập phân trong nghiệp vụ MVP.
- Discount phần trăm làm tròn xuống đến đồng ở bước cuối phép tính.
- Mỗi invoice tối đa một discount: `PERCENTAGE` hoặc `FIXED_AMOUNT`.
- Discount tính trên học phí gốc và không vượt học phí gốc.
- Invoice lưu snapshot base amount, discount type/value và final amount; thay đổi course fee không đổi invoice đã tạo.

### Invoice

- `dueDate` bắt buộc khi invoice được chốt/phát hành.
- Trạng thái: `PENDING`, `PARTIAL`, `COMPLETED`.
- `outstanding = finalAmount - payments + approvedRefunds/adjustments` theo ledger bất biến.
- Invoice overdue khi `today > dueDate` và `outstanding > 0`.

### Payment, adjustment và refund

- Payment gốc append-only; không sửa/xóa.
- STAFF được ghi payment thường bằng `CASH` hoặc `BANK_TRANSFER`.
- Payment và cập nhật ledger/invoice status phải cùng transaction.
- Dùng idempotency key; external bank reference nếu có phải unique trong phạm vi phù hợp.
- Adjustment/refund là record riêng, bắt buộc lý do và audit.
- Người tạo yêu cầu có thể là STAFF; người duyệt là MANAGER/ADMIN khác người tạo.
- Refund hỗ trợ `CASH` hoặc `BANK_TRANSFER`, không vượt số tiền đã thu còn lại.
- Không tự refund khi Student chuyển RESERVED/DROPPED.

### Số chứng từ

- Invoice: `INV-{branchCode}-{YYYY}-{000001}`.
- Receipt: `RC-{branchCode}-{YYYY}-{000001}`.
- Sequence độc lập theo loại chứng từ + branch + năm; không tái sử dụng số sau rollback/hủy.

## 9. Audit, receipt và FR-20

Audit tối thiểu cho create/update/delete, branch transfer, duplicate override, lock/unlock attendance/grade, payment, adjustment/refund và failed authorization quan trọng. Redact password/token/secret/PII; lưu actor, branch, resource, record ID, action, time, IP và reason. Audit persistence không được fire-and-forget.

Receipt PDF nội bộ gồm số phiếu, thời điểm, branch, student, invoice, số tiền, phương thức, reference và người thu.

FR-20 gồm tổng nợ, số học viên còn nợ, tổng quá hạn và bảng filter theo branch/date/student/status; có pagination/export; Manager/Admin/Staff chỉ thấy branch được phép.

## 10. Definition of Ready/Done

### Ready

- Story có actor, scope, permission, request/response, error codes, transaction/audit rule và test cases.
- Migration impact được xác định; không dùng `any` cho mutation.
- Không có câu hỏi mở ảnh hưởng đến dữ liệu hoặc tiền.

### Done

- Migration chạy trên database sạch.
- DTO + validation + allowlist field.
- RBAC/branch isolation được test bằng ít nhất hai branch.
- API, UI, loading/empty/error/permission states hoàn chỉnh.
- Dữ liệu còn sau reload.
- Unit + integration test phù hợp; finance có test transaction/idempotency.
- Audit và security response review pass.

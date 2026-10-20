# Dev Handoff — DreamHigh Operational MVP

**Phiên bản:** 0.1  
**Ngày bàn giao:** 19/10/2026  
**Nguồn chuẩn:** `Business_Decision_Register_MVP_v0.2.md`, PRD FR-01–FR-20, SRS Module 01/02, ERD và implementation artifacts.

## 1. Mục tiêu bàn giao

Triển khai đủ FR-01–FR-20 thành các vertical slice có dữ liệu thật, backend enforce quyền, frontend không còn mock trong luồng đã hoàn tất, dữ liệu tồn tại sau reload và có test phù hợp.

Không triển khai trong MVP: QBO, SePay, SMS/Zalo automation, portal, mobile app, payment gateway/QR, VAT e-invoice, dashboard KPI nâng cao, chat và AI analytics.

## 2. Quy tắc bắt buộc cho mọi slice

- Backend là nguồn thực thi authorization; không coi ẩn menu frontend là bảo mật.
- Không tin `branchId` từ client; suy ra scope từ JWT/user policy.
- Không dùng `any` cho mutation request; mọi request có DTO + class-validator.
- Không spread raw request body vào Prisma; allowlist field.
- Response không được lộ passwordHash, googleSub, token, secret hoặc PII không cần thiết.
- Mutation nghiệp vụ có transaction khi chạm nhiều bản ghi.
- Payment dùng idempotency; payment gốc append-only.
- Audit mutation, lock/unlock, branch transfer, duplicate override, payment/adjustment/refund và failed authorization quan trọng.
- Khi conflict hoặc business rule fail, trả lỗi có mã ổn định, message an toàn và field/context cần thiết.

## 3. RBAC và branch matrix

| Nghiệp vụ | ADMIN | MANAGER | STAFF | TEACHER |
|---|---:|---:|---:|---:|
| Cross-branch read/report | Có | Không | Không | Không |
| Catalog CRUD | Có | Có trong scope | Read | Read |
| User/role/branch config | Có | Không | Không | Không |
| Student/Lead create/update | Có | Có trong scope | Có trong scope | Read theo phân công |
| Class/session scheduling | Có | Có trong scope | Theo quyền vận hành | Read lớp được giao |
| Attendance nhập | Có | Có | Có | Lớp được giao |
| Attendance unlock | Có | Có | Có | Không |
| Grade nhập | Có | Có | Theo quyền | Lớp được giao trước lock |
| Grade unlock | Có | Có | Không | Không |
| Payment thường | Có | Có | Có | Không |
| Adjustment/refund request | Có | Có | Có | Không |
| Adjustment/refund approve | Có, khác người tạo | Có, khác người tạo | Không | Không |
| Branch transfer | Có | Không | Không | Không |

Mọi dữ liệu `Lead`, `Student`, `Class`, `Session`, `Invoice`, `Payment` và report tài chính phải truy ra được branch owner. Teacher phải đồng thời thuộc branch và được phân công lớp/session.

## 4. State và business rules

### Student

```text
ACTIVE ↔ RESERVED
ACTIVE → DROPPED
ACTIVE → GRADUATED
RESERVED → ACTIVE
```

Cấm `RESERVED → GRADUATED`. Mỗi transition cần reason, actor, timestamp, history và audit trong transaction. `RESERVED`/`DROPPED` không tự xóa enrollment, hủy invoice, refund hoặc xóa debt.

### Course/Class/Session

Course:

```text
KHỞI TẠO → ĐANG MỞ → ĐANG HỌC → HOÀN THÀNH
                                  ↘ NGỪNG
```

Giữ enum backend hiện có cho Class: `PLANNED`, `ACTIVE`, `COMPLETED`, `CANCELLED`; giữ Session: `NORMAL`, `RESCHEDULED`, `CANCELLED`, đồng thời bổ sung cơ chế hoàn thành/khóa theo thiết kế đã được duyệt. Course bắt đầu khi session đầu tiên `COMPLETED` hoặc attendance session đầu tiên bị khóa, tùy sự kiện đến trước. Sau đó không đổi level/Syllabus.

- Syllabus bắt buộc trước khi Course sang `ĐANG HỌC`.
- Class không vượt `maxStudents`, không enrollment trùng.
- Conflict: `newStart < existingEnd && newEnd > existingStart`; chặn cùng teacher hoặc room.
- Không reschedule session đã completed hoặc attendance locked.
- Session cancelled không attendance hợp lệ, không tính teacher hours.
- Chuyển class cần source/target, effective date, reason và audit.

### Attendance

- Status: `PRESENT`, `ABSENT_EXCUSED`, `ABSENT_UNEXCUSED`.
- Unique `(sessionId, studentId)`.
- Teacher được nhập/sửa trong 48 giờ sau `endTime` hoặc tới lúc session lock, tùy mốc sớm hơn.
- Manager/Staff unlock có reason/audit.
- Cảnh báo từ 2 session liên tiếp `ABSENT_UNEXCUSED`; excused ngắt chuỗi.

### Exam/Grade

- Chỉ `MIDTERM`, `FINAL`; mỗi class tối đa một exam mỗi loại.
- Score `0..100`; tổng weight của class ≤100%.
- Teacher nhập trước lock; Manager/Admin unlock với reason/audit.
- Lưu before/after grade khi thay đổi.
- MVP chưa tự động cảnh báo điểm thấp.

### Teacher hours

- Kỳ tháng lịch.
- Chỉ session `COMPLETED`; cancelled không tính.
- Rescheduled tính một lần theo session hoàn thành cuối.
- Teacher thay phải lưu teacher thực tế và Manager duyệt ngoại lệ.
- Manager close kỳ; Admin reopen với reason/audit.

### Finance

- Tiền VND nguyên; phần trăm discount làm tròn xuống ở bước cuối.
- Invoice có một discount snapshot: percentage hoặc fixed amount; không vượt base amount.
- Invoice chốt phải có dueDate; overdue khi `today > dueDate` và outstanding > 0.
- Payment append-only, `CASH`/`BANK_TRANSFER`, transaction + idempotency.
- Adjustment/refund record riêng; người duyệt MANAGER/ADMIN khác người tạo; refund CASH/BANK không vượt số đã thu còn lại.
- Invoice: `INV-{branchCode}-{YYYY}-{000001}`; receipt: `RC-{branchCode}-{YYYY}-{000001}`. Sequence độc lập theo loại + branch + năm, không tái sử dụng.

## 5. API contract baseline

Tất cả endpoint dùng envelope:

```json
{
  "statusCode": 200,
  "message": "Success",
  "data": {},
  "meta": {}
}
```

Lỗi dùng HTTP status phù hợp và error code ổn định; không trả raw Prisma error.

### Slice 0 — Platform/security

- `POST /auth/login`, `/auth/register`, `/auth/google`: DTO, secret fail-fast, public user mapper.
- Bổ sung policy/guard dùng `user.roles`, `user.branchIds`, `isSuperAdmin` và resource ownership.
- `GET /users`, user mutations: explicit select, không trả credential.
- Chuẩn hóa ValidationPipe với whitelist + forbid non-whitelisted + transform.
- Audit persistence phải await/transaction-safe; redact đệ quy.

### Slice 1 — Catalog/Course/Syllabus

- Giữ catalog API hiện có nhưng thay body `any` bằng DTO và enforce SRS Module 01.
- Course CRUD/lifecycle phải validate level/program/status và Syllabus trước `ĐANG HỌC`.
- Cần migration cho Syllabus/Unit/Lesson nếu triển khai trong MVP.

### Slice 2 — Class/Enrollment/Session

- `POST /classes` tạo class + generate sessions trong transaction.
- `GET /classes`, `GET /classes/:id`, `PATCH /classes/:id`, lifecycle mutation.
- `POST /classes/:id/enrollments`, chuyển/rút lớp theo rule và audit.
- `POST /sessions/preview`, `POST /sessions/generate` hoặc contract tương đương.
- Conflict response phải nêu resource và session đang xung đột.

### Slice 3 — Schedule/Teacher hours

- `PATCH /sessions/:id/reschedule`, `/swap-teacher`, `/change-room`, `/cancel`.
- `GET /teachers/me/schedule` cho teacher được xác thực.
- `GET /reports/teacher-hours?from=&to=` theo tháng; close/reopen kỳ có quyền và audit.

### Slice 4 — Attendance/alert

- `GET /sessions/:id/attendance`.
- `POST/PATCH /sessions/:id/attendance` bulk, unique theo session/student.
- `POST /sessions/:id/attendance/unlock` cho role hợp lệ.
- `GET /alerts/attendance-risk` hoặc field cảnh báo trong class detail.

### Slice 5 — Exam/Grade

- `POST /classes/:id/exams`, `GET /classes/:id/exams`.
- `PUT/PATCH /exams/:id/grades` bulk hoặc per student.
- `POST /exams/:id/lock`, `/unlock` với reason.
- Validate exam type unique, score và tổng weight.

### Slice 6 — Finance/receipt

- Fee/pricing CRUD theo course/class.
- `POST /invoices`, `GET /invoices/:id`, chốt invoice.
- `POST /payments` với idempotency key.
- Adjustment/refund request + approval riêng, khác người tạo.
- `GET /payments/:id/receipt.pdf` với branch authorization.

### Slice 7 — Debt dashboard

- `GET /reports/arrears` với filter branch/date/student/status, pagination và aggregate.
- Chỉ trả dòng outstanding > 0; đánh dấu overdue theo dueDate.
- Export phải áp dụng cùng authorization/filter với list.

## 6. Frontend requirements

Thay mock trong các route chính: `/classes/schedule`, `/classes/:id`, `/hr/teachers`, course detail/curriculum, attendance modal, grade/progress, finance/receipt và dashboard debt.

Mỗi query/mutation phải có loading, empty, error/retry, permission denied, conflict warning, unsaved-change confirmation và success feedback. Không cập nhật state giả thay cho refetch/invalidation; kiểm tra dữ liệu còn sau reload.

## 7. Acceptance criteria theo FR

- **FR-01/02/03/04:** catalog/user/RBAC/branch/audit thật; payload lạ bị từ chối; cross-branch test pass; response không lộ secret.
- **FR-05/06:** tạo/tìm/detail/status student thật; duplicate warning/override có reason; transition invalid bị 4xx; history transaction.
- **FR-07/08/09:** course/Syllabus/class/session tồn tại sau reload; generate session; capacity/duplicate/overlap bị chặn; reschedule/swap/cancel kiểm tra conflict và audit.
- **FR-10/11:** teacher chỉ thấy lịch được giao; report tháng tính đúng completed, không double-count; close/reopen có quyền.
- **FR-12:** placement score được lưu, validate student/class/branch và trả recommendation theo bảng ngưỡng được cấu hình.
- **FR-13/14:** attendance bulk lưu/đọc khớp; lock window/role đúng; cảnh báo 2 vắng không phép liên tiếp.
- **FR-15:** MIDTERM/FINAL, score 0–100, weight ≤100; lock/unlock và history hoạt động.
- **FR-16/17:** pricing/discount snapshot; không discount vượt base; invoice breakdown đúng.
- **FR-18/19:** payment transaction/idempotency; status/outstanding đúng; receipt PDF mở được và khớp dữ liệu.
- **FR-20:** arrears/overdue aggregate/list/filter/pagination/export đúng branch; không lộ branch khác.

## 8. Data/migration impact cần xử lý trước code

Schema hiện tại cần đánh giá migration cho: `branchId` trên Lead/Student/Invoice/Payment/AuditLog hoặc bảng ownership tương đương; Syllabus/Unit/Lesson; session completed/lock metadata; attendance/grade lock history; actual teacher assignment; class transfer history; finance ledger; discount snapshot; adjustment/refund; document sequences; idempotency keys; indexes theo branch/status/student/class/dueDate/time.

Không sửa dữ liệu thật hoặc chạy migration trên database dùng chung khi chưa có backup/rehearsal.

## 9. Test/DoD

- Unit: state machine, overlap, score/weight, discount, outstanding/overdue, invoice/receipt sequence.
- Integration PostgreSQL: migration, branch isolation, RBAC, transaction rollback, idempotency, lock/unlock.
- E2E: login → student → course/class/session → enrollment → attendance/alert → grade → invoice/discount/payment → receipt → debt report.
- Frontend: loading/empty/error/permission, conflict, lock confirmation, payment confirmation, PDF download.
- Chỉ đánh dấu story Done khi API + UI + persistence + audit + tests hoàn tất; không đánh dấu Done vì schema hoặc mock UI.

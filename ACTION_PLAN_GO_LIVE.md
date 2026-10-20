# DreamHigh — Action Plan hoàn thiện MVP và Go-Live

> **Mục đích:** Tài liệu thực thi dành cho AI/đội phát triển để hoàn thiện hệ thống theo từng phase, từ xử lý blocker đến UAT và Go-Live.
>
> **Nguồn yêu cầu:** `PRD_QuanLyDaoTao_TrungTamTiengAnh.md` — MVP gồm FR-01 đến FR-20.
>
> **Trạng thái hiện tại:** Chưa sẵn sàng UAT/Go-Live. Nền tảng IAM, catalog, CRM cơ bản và Prisma schema đã có; các luồng scheduling, attendance, grading, finance và dashboard chưa chạy end-to-end với dữ liệu thật.

---

## Nguyên tắc thực thi bắt buộc

1. Làm theo đúng thứ tự phase, không triển khai tính năng Phase 2/3 trước khi các blocker MVP được xử lý.
2. Mỗi vertical slice phải hoàn thiện đồng thời: database/migration, backend API, DTO/validation, RBAC/branch policy, frontend query/mutation, loading/error state, audit và test.
3. Không coi schema hoặc mock UI là tính năng đã hoàn thành. Chỉ đánh dấu Done khi có luồng API + UI + dữ liệu tồn tại sau reload + test.
4. Không dùng `any` cho request mutation và không spread raw request body vào Prisma.
5. Không tin `branchId` do client gửi. Backend phải suy ra và kiểm tra phạm vi branch từ authenticated user.
6. Không để secret, password, token hoặc PII nhạy cảm trong source, seed, log hay response.
7. Không tích hợp QBO, SePay, SMS/Zalo, mobile app hoặc payment gateway vào blocker MVP nếu PRD chưa thay đổi.
8. Trước mỗi thay đổi lớn, đọc code hiện tại và kiểm tra git status. Không xóa hoặc ghi đè thay đổi chưa được xác nhận.

---

# Phase 0 — Chốt scope và xử lý blocker bảo mật

**Thời lượng định hướng:** 3–5 ngày  
**Ưu tiên:** P0  
**Mục tiêu:** Loại bỏ rủi ro có thể làm mất an toàn hệ thống trước khi xây module mới.

## Công việc

### Security blocker

- Xóa JWT secret fallback tại:
  - `pms-eng-api/src/modules/auth/auth.module.ts`
  - `pms-eng-api/src/modules/auth/strategies/jwt.strategy.ts`
- Fail-fast khi `NODE_ENV=production` nhưng thiếu `JWT_SECRET`.
- Validate JWT secret đủ mạnh và đồng nhất signing/verification.
- Tách seed development khỏi production.
- Xóa email/password admin hard-coded khỏi `pms-eng-api/prisma/seed.ts`.
- Không reset password hoặc bật `isSuperAdmin` mỗi lần chạy seed.
- Dùng cơ chế bootstrap credential an toàn qua environment/secret manager.
- Chốt chiến lược token: ưu tiên HttpOnly Secure SameSite cookie; nếu giữ bearer token thì phải lập threat model và kiểm soát XSS.
- Hạn chế hoặc tắt public registration sau bootstrap.
- Bổ sung rate limit/login protection vào backlog bắt buộc.

### Chốt nghiệp vụ và scope

- Khóa MVP ở FR-01 đến FR-20.
- Chốt role: `ADMIN`, `MANAGER`, `STAFF`/Học vụ, `TEACHER`; chỉ chuẩn bị `STUDENT`/`PARENT` nếu chưa có portal.
- Chốt các quy tắc:
  - Syllabus có bắt buộc trước khi mở khóa hay không.
  - Ai được khóa/mở attendance và grade.
  - Quyền điều chỉnh, hoàn tiền hoặc hủy payment.
  - Quy tắc discount theo phần trăm/số tiền.
  - Quy tắc chuyển lớp, bảo lưu, nghỉ học, tốt nghiệp.
  - Công thức tính giờ dạy thực tế.
  - Chính sách duplicate parent/student/lead.

## Definition of Done

- Không còn secret/password production hard-coded.
- Có RBAC matrix được phê duyệt.
- Có danh sách FR-01–FR-20 và trạng thái hiện tại.
- Các quy tắc nghiệp vụ còn mơ hồ đã có quyết định bằng văn bản.
- Không bắt đầu module mới nếu Phase 0 chưa đạt.

---

# Phase 1 — Nền tảng dữ liệu, API contract và branch isolation

**Thời lượng định hướng:** 1–2 tuần  
**Ưu tiên:** P0  
**Mục tiêu:** Tạo nền tảng dữ liệu/API an toàn để các module nghiệp vụ dùng chung.

## Database

- Rà soát Prisma schema và migration từ database rỗng.
- Bổ sung/chốt branch ownership cho Student, Lead, Invoice, Payment và AuditLog.
- Bổ sung các entity cần thiết: `PlacementTest`, `TeacherProfile`, `Syllabus`, `SyllabusUnit/Lesson`, internal notification.
- Bổ sung index theo `branchId`, `status`, `studentId`, `classId`, `dueDate`, `startTime`.
- Kiểm tra unique constraint và transaction boundary.
- Chuẩn bị seed development không chứa credential production.

## Backend contract và validation

- Thay toàn bộ `@Body() body: any` bằng DTO có decorator.
- Bật `forbidNonWhitelisted: true` cùng `whitelist` và `transform`.
- Không spread raw body vào Prisma; allowlist field trong service.
- Chuẩn hóa response:

```json
{
  "statusCode": 200,
  "message": "Success",
  "data": {},
  "meta": {}
}
```

- Chuẩn hóa error code, HTTP status và global exception filter.
- Bổ sung request correlation ID.
- Map lỗi Prisma thành lỗi nghiệp vụ an toàn, không trả raw database error.

## RBAC, branch isolation và data exposure

- Tạo policy/guard/service dùng chung để kiểm tra `req.user.branchIds`.
- Mọi list/detail/create/update/delete phải scope theo branch; Admin/BGĐ mới được cross-branch.
- Không nhận branch scope từ client nếu không kiểm tra quyền.
- Kiểm tra IDOR với Student, Lead, Class, Invoice, Payment và Session.
- Dùng explicit `select`; không dùng `include: true` với `SystemUser`.
- Dùng public mapper, không trả `passwordHash`, `googleSub`, token hoặc secret.
- Xóa hard-coded `branchId: 1` ở frontend và backend.

## Test bắt buộc

- User branch A không đọc/sửa dữ liệu branch B.
- User không truyền branchId chỉ thấy branch được cấp.
- User gửi branchId giả bị từ chối.
- Admin có thể xem nhiều branch theo quyền.
- Payload chứa field lạ/field quan hệ bị từ chối.
- Response không lộ credential hoặc dữ liệu nội bộ.

## Definition of Done

- Tất cả mutation chính dùng DTO và allowlist field.
- Branch isolation có integration test.
- Không còn mass assignment và sensitive relation leak đã biết.
- Migration chạy được trên database sạch.
- RBAC được enforce ở backend, không chỉ ẩn menu frontend.

---

# Phase 2 — Luồng đào tạo cốt lõi

**Thời lượng định hướng:** 3–4 tuần  
**Ưu tiên:** P0  
**Mục tiêu:** Hoàn thiện vertical slice vận hành lớp học bằng dữ liệu thật.

```text
Course → Class → Session → Enrollment
       → Attendance → Absence Alert
       → Exam/Grade → Feedback
```

## 2.1 Course và Syllabus

- Hoàn thiện Course API và lifecycle.
- Bổ sung Syllabus/Unit/Lesson nếu thuộc MVP.
- Version/lock syllabus theo quyết định nghiệp vụ.
- Kiểm tra level, total sessions, duration và trạng thái catalog.
- Không cho chỉnh dữ liệu đã khóa hoặc đã được sử dụng trái quy tắc.

## 2.2 Class và enrollment

- Tạo module Classes đầy đủ: create, update, list, detail, lifecycle.
- API enrollment, kiểm tra sĩ số và chống ghi danh trùng.
- Hỗ trợ chuyển lớp, bảo lưu, rút lớp nếu thuộc scope.
- Audit thay đổi class/enrollment.

## 2.3 Schedule/Session

- Tạo module Schedule/Sessions.
- CRUD session và sinh buổi từ lịch khóa.
- Conflict detection theo:
  - Giáo viên.
  - Phòng.
  - Khung giờ.
  - Chi nhánh.
- Hỗ trợ dời lịch, đổi phòng, đổi giáo viên, hủy buổi.
- Lưu lịch sử thay đổi.
- API lịch cá nhân giáo viên và giờ dạy thực tế.
- Kiểm tra overlap theo khoảng thời gian, không chỉ trùng start time.

## 2.4 Attendance

- API lấy danh sách học viên theo session.
- Ghi nhận Present, Absent Excused, Absent Unexcused.
- Chặn học viên không thuộc lớp.
- Khóa/mở attendance theo quyền.
- Cảnh báo vắng liên tiếp.
- Audit điều chỉnh sau khi khóa.

## 2.5 Assessment/Grade

- API Exam, Grade và feedback.
- Validate score range và tổng weight.
- Nhập điểm hàng loạt.
- Khóa bảng điểm.
- Phân quyền Teacher/Staff/Manager.
- Sinh report card hoặc dữ liệu báo cáo kết quả.

## Frontend

Thay mock bằng React Query query/mutation tại các màn hình:

- `dreamhigh-web/src/pages/Classes/ClassScheduleManagement.tsx`
- `dreamhigh-web/src/pages/Courses/CourseDetail.tsx`
- `dreamhigh-web/src/pages/HR/TeacherManagement.tsx`
- `dreamhigh-web/src/pages/ClassDetailsPage.tsx`

Bổ sung loading, empty, error/retry, permission denied, conflict warning và confirm dialog cho thao tác khóa/hủy.

## Definition of Done

Luồng sau chạy được và dữ liệu còn sau reload:

```text
Create course
→ Create class
→ Create session
→ Enroll student
→ Take attendance
→ Show absence warning
→ Enter grade/comment
```

- Không còn mock trong màn hình nghiệp vụ cốt lõi.
- Có unit/integration test cho conflict, attendance và grade.
- Teacher chỉ thấy session/class đúng phạm vi.
- Mutation quan trọng có audit.

---

# Phase 3 — Tài chính, báo cáo và frontend MVP

**Thời lượng định hướng:** 2–3 tuần  
**Ưu tiên:** P0  
**Mục tiêu:** Hoàn thành FR-16 đến FR-20 và thay dashboard mock bằng dữ liệu thật.

## Finance backend

Tạo module Finance gồm:

- Fee plan theo course/class.
- Discount theo phần trăm hoặc số tiền.
- Invoice create/view/cancel/adjust theo quyền.
- Payment cash/bank transfer và phương thức được phê duyệt.
- Tính total, discount, paid, outstanding.
- Cập nhật `PENDING`, `PARTIAL`, `COMPLETED`.
- Idempotency/chống payment trùng.
- Transaction invoice/payment.
- Audit mọi mutation tài chính.

## Receipt PDF

- Tạo endpoint xuất phiếu thu PDF.
- Có số phiếu, ngày thu, học viên, nội dung, số tiền, phương thức và người lập.
- Không sửa payment đã hoàn tất ngoài adjustment/refund workflow.
- Kiểm tra font tiếng Việt và khả năng in.

## Debt dashboard

- API/UI danh sách còn nợ và quá hạn.
- Tổng thu theo thời gian/branch.
- Invoice chưa thanh toán và payment history.
- Filter branch/date/course/status.
- Pagination và export.
- Thay mock tại:
  - `dreamhigh-web/src/pages/Dashboard/DashboardHome.tsx`
  - `dreamhigh-web/src/pages/Dashboard/DashboardSummary.tsx`
- Thêm route Finance vào `dreamhigh-web/src/App.tsx`.

## Student và import/export

- Hoàn thiện create/edit student bằng API thật.
- Cập nhật parent contact và branch.
- Hiển thị enrollment, attendance, grade, invoice trong detail.
- Import/export Excel cho Student, Parent, Course, Class.
- Có preview, lỗi theo dòng, duplicate handling, rollback và audit.

## Definition of Done

Luồng sau chạy được:

```text
Student
→ Invoice
→ Discount
→ Payment
→ Debt balance
→ Receipt PDF
→ Debt dashboard
```

- Dashboard dùng API thật.
- Không còn route Finance giả.
- Payment không ghi nhận trùng.
- PDF được nghiệp vụ xác nhận.
- Import dữ liệu mẫu thành công và báo lỗi chính xác.

---

# Phase 4 — QA, security hardening và performance

**Thời lượng định hướng:** 2 tuần  
**Ưu tiên:** P1/P0 trước UAT  
**Mục tiêu:** Chứng minh hệ thống an toàn, ổn định và đáp ứng NFR.

## Testing

### Backend

- Unit test student lifecycle, schedule conflict, absence warning, grade validation, invoice/payment, discount.
- Integration test với PostgreSQL thật cho migration, RBAC, branch isolation và transaction.
- E2E test login, Lead conversion, create class, attendance, grade, invoice/payment và receipt.

### Frontend

- Test ProtectedRoute, role menu, form validation, loading/error, attendance và payment.
- Test responsive desktop/tablet.
- Bổ sung frontend test script và coverage threshold.

## Security hardening

- Rate limit login/register.
- Brute-force protection/lockout.
- Idle timeout 30 phút.
- CORS production allowlist và fail-fast nếu thiếu config.
- Giới hạn Vite `allowedHosts`, không dùng `true` ở môi trường public.
- Security headers.
- Trusted proxy policy cho client IP.
- Redaction đệ quy trong audit.
- Audit failed events và sửa cơ chế `tap(async ...)` không await.
- Không trả raw Prisma error.
- Dependency vulnerability scan và secret scanning.

## Performance và Ops

- Load test ít nhất 10.000 học viên.
- Kiểm tra search/filter grid <2 giây, report <5 giây.
- Phân tích query plan, index, pagination và connection pool.
- Structured logging, correlation ID, error tracking, metrics và alert.
- Health/readiness check có kiểm tra database.
- Backup/restore và migration rollback test.

## CI/CD

Cập nhật `.github/workflows/ci.yml` để có:

- PostgreSQL service.
- Prisma validate/migrate.
- Seed test an toàn.
- Unit/integration/e2e test.
- Frontend lint/build/test.
- Coverage report.
- Guard khi thiếu `JWT_SECRET`, `CORS_ORIGINS`, `VITE_API_URL`.

## Responsive bắt buộc trước UAT

- Sửa padding cố định trong `AppLayout.tsx` theo breakpoint.
- Thêm mobile navigation khi Sidebar bị ẩn dưới `md`.
- Bọc bảng bằng `overflow-x-auto` hoặc tạo card layout.
- Kiểm tra `AttendanceModal.tsx`, bảng CRM/Admin và `ClassDetailsPage.tsx` trên tablet.

## Definition of Done

- CI pass trên runner sạch.
- PostgreSQL integration test chạy thật.
- Không còn Critical/High security finding chưa xử lý.
- Đạt mục tiêu hiệu năng đã thống nhất.
- Có log, health check và error tracking tối thiểu.
- UI vận hành chính dùng được trên desktop và tablet.

---

# Phase 5 — UAT, migration và Go-Live

**Thời lượng định hướng:** 1–2 tuần  
**Ưu tiên:** P0  
**Mục tiêu:** Nghiệm thu nghiệp vụ và triển khai production có kiểm soát.

## UAT theo persona

### Admin

- User, role, branch, catalog và audit.

### Quản lý đào tạo

- Course/class, schedule, đổi giáo viên/phòng, báo cáo.

### Học vụ

- Student, enrollment, attendance, invoice, payment, receipt và debt.

### Giáo viên

- Lịch cá nhân, lớp, attendance, grade/comment và cảnh báo vắng.

### Tư vấn tuyển sinh

- Lead, placement test, conversion và gán lớp.

## Data migration

- Làm sạch Excel cũ theo template.
- Mapping field và import staging.
- Đối soát Student, Parent, Course, Class, Invoice.
- Nghiệm thu dữ liệu bởi nghiệp vụ.
- Backup trước migration production.
- Dress rehearsal migration và rollback.

## Go-Live checklist

- Production secrets đã cấu hình và không có fallback.
- HTTPS hoạt động.
- CORS đúng domain.
- Migration thành công.
- Backup/restore đã thử.
- Health/readiness check hoạt động.
- Smoke test login, RBAC, student, class, attendance, invoice, payment, receipt, audit.
- Có rollback plan.
- Có người trực hỗ trợ/hypercare.
- Có user guide, admin guide, deployment runbook và incident procedure.

## Definition of Done

- Product Owner ký UAT acceptance cho FR-01 đến FR-20.
- Không còn blocker/critical bug.
- Migration được nghiệm thu.
- Người dùng hoàn thành đào tạo.
- Production smoke test pass.
- Có kế hoạch hỗ trợ và đo lường sau go-live.

---

# Phase 6 — Tính năng sau MVP

**Chỉ bắt đầu sau khi MVP ổn định qua ít nhất một chu kỳ vận hành.**

- Email/SMS/Zalo automation.
- Parent/student portal.
- Payment gateway và QR payment.
- Hóa đơn VAT điện tử.
- QBO/SePay.
- Mobile app.
- Dashboard nâng cao.
- AI analytics.
- Chat nội bộ.

## Điều kiện chuyển Phase 6

- Không còn lỗi tài chính nghiêm trọng.
- Attendance, grade và invoice được nghiệp vụ xác nhận.
- Có số liệu thực tế về uptime, latency, active users, sai lệch công nợ và lỗi vận hành.

---

# Bảng ưu tiên thực thi

| Ưu tiên | Hạng mục |
|---|---|
| P0 | JWT secret, seed credential, branch isolation, DTO/mass assignment |
| P0 | Class/schedule API và persistence |
| P0 | Attendance/grade API |
| P0 | Finance/payment/receipt/debt API |
| P1 | Thay mock frontend bằng API thật |
| P1 | Dashboard, import/export, internal notification |
| P1 | PostgreSQL integration/e2e test và CI |
| P1 | Responsive tablet |
| P2 | Monitoring, performance, backup/restore, security hardening |
| P3 | SMS/Zalo, parent portal, payment gateway, QBO/SePay |

---

# Mốc phát hành

- **Sẵn sàng bắt đầu UAT:** hoàn thành Phase 0–3 và các kiểm thử bắt buộc của Phase 4.
- **Sẵn sàng Go-Live:** hoàn thành Phase 0–5.
- **Sẵn sàng mở rộng Phase 6:** MVP ổn định, dữ liệu và chỉ số vận hành được xác nhận.

---

# Quy tắc cập nhật trạng thái cho AI

Khi thực hiện từng task:

1. Đọc file/code liên quan trước khi sửa.
2. Xác định task thuộc phase nào và dependency nào đã đạt.
3. Sửa phạm vi nhỏ nhất cần thiết, không thêm tính năng ngoài task.
4. Viết hoặc cập nhật test ngay cùng vertical slice.
5. Chạy kiểm tra phù hợp: lint, typecheck, unit, integration, build hoặc browser test.
6. Không đánh dấu Done nếu chỉ compile được nhưng chưa chạy được luồng nghiệp vụ.
7. Báo cáo theo mẫu:

```text
Task:
Phase:
Files changed:
Implementation:
Tests run:
Result:
Remaining risks:
Next dependency:
```

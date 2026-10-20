# Lộ trình Code Hoàn thiện Nghiệp vụ — DreamHigh PMS (MVP)

> **Mục đích:** Chuyển các test case `GAP` trong `docs/qa/Test_Case_Suite_MVP.md` thành công việc code cụ thể, theo thứ tự phụ thuộc, kế thừa đúng kiến trúc hiện có (NestJS + Prisma + PostgreSQL; React 19 + Vite + Zustand + React Query).
> **Liên kết:** `ACTION_PLAN_GO_LIVE.md` (phase gốc), `_bmad-output/planning-artifacts/architecture/*`, `_bmad-output/implementation-artifacts/*`.
> **Nguyên tắc:** Minimal Diff · Zero Regression · Consistency · Test-first cho từng vertical slice.

## Quy ước trạng thái

`✅ DONE` (đã có code) · `🔵 CÓ CODE - cần test` · `⚪ GAP` (chưa có code) · `🔶 PARTIAL` (có 1 phần) · `🟡 MOCK` (FE mock).

---

## Bức tranh hiện trạng (đối chiếu code thực tế)

| Module backend | Trạng thái | Ghi chú |
|---|---|---|
| `auth` | 🔶 PARTIAL | Login/Register/Google OK; **JWT secret fallback** còn, chưa HttpOnly cookie. |
| `users` (IAM/RBAC) | 🔵 CÓ CODE | CRUD user đa role/branch OK; test `users.service.spec.ts` có sẵn. |
| `categories` | 🔵 CÓ CODE | Full CRUD program/level/class-type/room/course + guard FK; `body: any` (chưa DTO). |
| `students` | 🔵 CÓ CODE | CRUD + state-machine OK; `data: any` (mass assignment), list chưa scope branch bắt buộc. |
| `leads` | 🔵 CÓ CODE | CRUD lead. |
| `enrollment` | 🔶 PARTIAL | convert Lead→Student OK; placement test **hardcode barem, không lưu DB**. |
| `classes` | 🔶 PARTIAL | Chỉ `GET /classes/:code`; **thiếu create/update/lifecycle**. |
| **`schedule` / `sessions`** | ⚪ GAP | **Chưa có module**. FR8/FR9/FR10/FR11 chưa có endpoint. |
| **`attendance`** | ⚪ GAP | Bảng `Attendance` có trong Prisma, **chưa có API**. |
| **`grades`** | ⚪ GAP | Bảng `Exam`, `Grade` có, **chưa có API**. |
| **`finance`** (invoice/payment/receipt/arrears) | ⚪ GAP | Bảng `Invoice`, `Payment` có, **chưa có API**. |
| `audit` | 🔵 CÓ CODE | `GET /audit-logs` + interceptor (chưa await). |
| **Notifications / Alerts** | ⚪ GAP | Chưa có entity/API (FR14 phụ thuộc). |

| Frontend | Trạng thái |
|---|---|
| Auth, IAM, Categories, Courses, CRM (leads/students), Profile | ✅ nối API thật |
| Dashboard, Classes/Schedule, Courses (detail/curriculum), HR, Finance | 🟡 mock |
| Route Finance | ⚪ Chưa có router |

---

## Nguyên tắc kỹ thuật bắt buộc (áp dụng mọi bước)

1. **Envelope:** tuân `architecture/03`, dùng helper `ApiResponse<T>` ở `src/common/interceptors` hoặc service-level (như `auth`/`students` đang làm).
2. **DTO + validation:** mọi POST/PATCH → DTO `class-validator`; bật `forbidNonWhitelisted: true` trong `main.ts`.
3. **Branch isolation:** `@CurrentUser()` lấy `branchIds`; guard/service scope theo branch; **không tin `branchId` client**.
4. **Transaction:** mọi thao tác ghi nhiều bảng (schedule, attendance, invoice+payment, enrollment) dùng `prisma.$transaction`.
5. **Audit:** mọi mutation tài chính/grade/attendance phải đi qua interceptor (sửa `tap(async → concatMap`).
6. **Test:** mỗi service mới → unit spec (mock Prisma) cùng thư mục; integration ở Phase E.
7. **FE:** React Query query/mutation + `apiClient`; loading/empty/error/confirm dialog.

---

## Lộ trình theo Phase & Story

### Phase A — Hardening nền tảng (P0) — ~1 tuần

Mục tiêu: đưa nền tảng chạm `GAP` đầu tiên gây rủi ro bảo mật & contract.

| Bước | File | Việc cần làm | Test |
|---|---|---|---|
| A1 | `pms-eng-api/src/modules/auth/auth.module.ts`, `strategies/jwt.strategy.ts` | Xóa secret fallback; fail-fast khi prod thiếu `JWT_SECRET` | 1.1-TC-08 |
| A2 | `pms-eng-api/prisma/seed.ts` | Tách seed dev/prod, bỏ credential hard-coded | — |
| A3 | `pms-eng-api/src/main.ts` | Bật `forbidNonWhitelisted: true`; global exception filter; correlation ID | X-TC-01 |
| A4 | `categories`, `students`, `enrollment` controller | Thay `@Body() body: any` bằng DTO; allowlist field trong service | 1.2-TC-09, 2.1-TC-06 |
| A5 | `common/interceptors/audit.interceptor.ts` | Chờ promise audit (tránh unhandled); redaction đệ quy | 1.4-TC-07 |
| A6 | `common/` | `BranchScope` guard/service dùng chung | X-TC-03 |

**DoD:** A1–A6 xong; unit test pass; không còn `body: any`.

---

### Phase B — Scheduling & Sessions (Epic 3: FR8, FR9, FR10, FR11) — P0 — ~1.5 tuần

Đây là **module lớn nhất còn thiếu**. Tạo mới theo pattern `categories`/`students`.

**B1. Schema & migration** (`prisma/schema.prisma`)
- `Session` đã có (`classId, roomId, startTime, endTime, status, topicNote`).
- Bổ sung cột lưu lịch sử dời: bảng `SessionChange` (`sessionId, changedBy, fromStart, toStart, reason, createdAt`) hoặc dùng `AuditLog`. → khuyến nghị bảng riêng cho truy vấn.
- Index thêm `(roomId, startTime)` & `(classId, startTime)` nếu thiếu.

**B2. Conflict utility** (thuần, dễ test) → `src/modules/schedule/utils/conflict.util.ts`
```
overlaps(aStart, aEnd, bStart, bEnd) =
  new Date(aStart) < new Date(bEnd) && new Date(aEnd) > new Date(bStart)
```
Test: 3.1-TC-04, 3.1-TC-05.

**B3. `ScheduleService`** (`src/modules/schedule/`)
- `createClassSchedule(dto)`: tạo class + sinh N session trong transaction; trước khi lưu kiểm tra conflict GV/phòng.
- `rescheduleSession(id, dto)`: dời 1 + tịnh tiến các session sau (delta).
- `swapTeacher(id, dto)` / `changeRoom`.
- `getTeacherSchedule(teacherId, range)`.
- `getTeachingHours(from, to)`: Σ(end-start) session đã diễn ra, loại CANCELLED.
- Error 422 với message nêu tên GV/phòng lớp xung đột.

**B4. `ScheduleController`** (~`/api/sessions`, `/api/classes/:id/schedule`)
| Endpoint | Role | Test |
|---|---|---|
| `POST /classes/:id/sessions/generate` | ADMIN, MANAGER | 3.1-TC-01/02/03 |
| `PATCH /sessions/:id/reschedule` | ADMIN, MANAGER | 3.2-TC-01/03/04 |
| `PATCH /sessions/:id/teacher` | ADMIN, MANAGER | 3.2-TC-02 |
| `GET /sessions/my-schedule` | TEACHER | 3.3-TC-01/02 |
| `GET /reports/teaching-hours` | ADMIN, MANAGER, STAFF | 3.4-TC-01/02/03 |

**B5. Mở rộng `ClassesService`** thêm `create/update/getDetail/list` (hiện chỉ `getClassDetails`) + lifecycle `PLANNED→ACTIVE→COMPLETED/CANCELLED` + fix rò `teacher` (dùng public mapper). Test 4.1-TC-03/04.

**B6. FE:** thay mock `ClassScheduleManagement.tsx`, `ClassModal.tsx`, `ClassDetailsPage.tsx`, `TeacherDetail.tsx` bằng React Query; thêm loading/error/conflict warning.

**DoD (test tự động):** `conflict.util.spec.ts`, `schedule.service.spec.ts`, `classes.service.spec.ts` pass; luồng tạo lớp → sinh session → đổi GV chạy E2E mock DB.

---

### Phase C — Vận hành lớp: Attendance & Grades (Epic 4: FR13, FR14, FR15) — P0 — ~1.5 tuần

**C1. `AttendanceService`** (`src/modules/attendance/`)
- `bulkUpsert(sessionId, dto[])`: mọi `studentId` phải thuộc `ClassStudent` của lớp session; upsert theo unique `(sessionId, studentId)`.
- Guard quyền: GV phụ trách lớp (qua `class.teacherId`) hoặc ADMIN/MANAGER.
- Test: 4.2-TC-01..05.

**C2. `AttendanceRiskService`** (FR14) — `src/modules/attendance/attendance-risk.service.ts`
- Sau mỗi bulk upsert: EventEmitter `attendance.updated` → listener đếm chuỗi vắng liên tiếp (ngưỡng cấu hình `ATTENDANCE_ABSENCE_THRESHOLD`, default 3).
- Entity `AttendanceAlert` (`studentId, classId, consecutiveCount, detectedAt, resolved`).
- `GET /alerts/attendance-risk` (ADMIN, MANAGER, STAFF).
- Test: 4.4-TC-01..05.

**C3. `GradeService`** (`src/modules/grades/`)
- `GET /classes/:id/exams`, `POST /exams`, `bulkUpsertGrades(examId, dto[])`.
- Validate `score ∈ [0, maxScore]`; cảnh báo dưới ngưỡng; validate Σ weight.
- Test: 4.3-TC-01..04.

**C4. FE:** `AttendanceModal.tsx`, `ClassDetailsPage.tsx` (tab Results), `ClassFeedbackModal.tsx` nối API.

**DoD:** Luồng điểm danh → cảnh báo vắng; nhập điểm → lưu & cảnh báo thấp; unit test pass.

---

### Phase D — Tài chính & Báo cáo (Epic 5: FR16–FR20) — P0 — ~2 tuần + Placement Test (FR12)

**D1. Placement Test (Story 2.3)** — mở rộng `enrollment`
- Thêm model `PlacementTest (studentId, listening, reading, writing, totalScore, recommendedLevelId, testedAt)`.
- `recordPlacementTest` map barem **từ bảng cấu hình Level** (bảng lookup `PlacementBarem` hoặc cột min/max) → không hardcode.
- Test: 2.3-TC-06/07.

**D2. `FinanceService`** (`src/modules/finance/`)
- `FeePlan` (courseId/classId, amount, effectiveFrom/To), CRUD + soft deactivate.
- `Discount` (studentId, type PERCENT|FIXED, value, reason), validate ≤ base.
- `createInvoice`, `recordPayment` (transaction: payment + cập nhật `Invoice.paymentStatus` PENDING/PARTIAL/COMPLETED + outstanding), idempotency theo `transactionRef`.
- Calculation util `finance/utils/finance.util.ts` (testable): `applyDiscount`, `computeStatus`.
- Test: 5.1-TC-01..03, 5.2-TC-01..04, 5.3-TC-01..06.

**D3. Receipt PDF (Story 5.4)**
- `GET /api/invoices/:id/receipt` → PDF (thêm lib PDF phù hợp, hỗ trợ Unicode tiếng Việt).
- Test: 5.4-TC-01/03.

**D4. Arrears Dashboard (Story 5.5)**
- `GET /reports/arrears` (filter branch/date/status, pagination).
- Test: 5.5-TC-01..04.

**D5. FE:** `Finance/AdjustmentModal.tsx`, `PayrollSlipModal.tsx`, DashboardFinance, route `/finance` trong `App.tsx`.

**DoD:** Luồng Student → Invoice → Discount → Payment → Debt → Receipt → Dashboard chạy thật; transaction test pass.

---

### Phase E — QA, branch isolation, CI (mapped ACTION_PLAN Phase 4) — ~2 tuần

- Thiết lập Jest integration với PostgreSQL test service (`test/integration/` + `docker-compose.test.yml`), dùng `@nestjs/testing`.
- Bổ sung integration: branch isolation (X-TC-03), RBAC matrix, transaction rollback.
- E2E Playwright (cấu hình `dreamhigh-web/playwright.config.ts`).
- Bật CI `.github/workflows/ci.yml` có PostgreSQL, prisma migrate/seed test, coverage.
- Security: rate limit login, CORS allowlist, security headers, idle timeout.
- Responsive tablet (X-TC-07).

---

### Phase F — UAT & Go-Live (mapped ACTION_PLAN Phase 5)

- Chạy full test suite (unit + integration + E2E).
- Manual UAT theo persona (Admin/Quản lý/Học vụ/Giáo viên/Tư vấn) dùng các TC `UI`/`M`.
- Data migration, smoke test, runbook.

---

## Ma trận phụ thuộc (thứ tự bắt buộc)

```
Phase A (hardening/contract)
   └─> Phase B (schedule) ──┬─> Phase C (attendance) ─> C2 (alerts FR14)
                            └─> Phase B5 (classes detail mở rộng)
   └─> Phase D (finance)  [phụ thuộc classes/students đã ổn]
                          [D1 placement độc lập, có thể làm song song]
   └─> Phase E (integration/CI) cần schema đủ của B/C/D
   └─> Phase F (UAT)
```

**Không được** làm C (attendance) trước B (session/class) vì attendance gắn `sessionId`.
**Không được** làm D (invoice gắn `classId`) trước B.

---

## Ước lượng & thứ tự thực thi đề xuất

| Thứ tự | Phase | Stories / FR | Effort | Test cases mục tiêu |
|---|---|---|---|---|
| 1 | A | Hardening | 1 tuần | 1.1-TC-08, X-TC-01, 1.4-TC-07, 1.2-TC-09, 2.1-TC-06 |
| 2 | B1–B4 | Schedule FR8–11 | 1 tuần | 3.1, 3.2, 3.3, 3.4 |
| 3 | B5 | Classes detail | 0.5 tuần | 4.1-TC-01..04 |
| 4 | C1–C3 | Attendance/Grade FR13-15 | 1.5 tuần | 4.2, 4.3, 4.4 |
| 5 | D1 | Placement FR12 | 0.5 tuần | 2.3-TC-06/07 |
| 6 | D2–D4 | Finance FR16-20 | 2 tuần | 5.1–5.5 |
| 7 | D5 | FE Finance/Dashboard | 1 tuần | UI/M |
| 8 | E | Integration + CI | 2 tuần | X-TC-03, E2E |
| 9 | F | UAT + Go-Live | 1–2 tuần | Manual M |

**Tổng ~11–12 tuần** cho 1 dev full-stack + 0.5 QA (thuần MVP FR1–20).

---

## Checklist chấp nhận cho mỗi story (Definition of Done)

Trước khi đánh `✅`, bắt buộc:

- [ ] Migration + schema đúng, `prisma validate` pass.
- [ ] Endpoint + DTO + envelope + branch scope.
- [ ] Unit test trong cùng thư mục module, `npm test` pass.
- [ ] Test case trong `Test_Case_Suite_MVP.md` được đánh `DONE-CODE`.
- [ ] FE nối API (không còn mock) + loading/error state.
- [ ] Mutation có audit.
- [ ] Báo cáo theo format trong ACTION_PLAN:
  ```
  Task / Phase / Files changed / Implementation / Tests run / Result / Remaining risks / Next dependency
  ```

---

## Vùng không tự mở rộng (Out of scope MVP)

Theo ACTION_PLAN Phase 6: QBO/SePay, SMS/Zalo, parent portal, payment gateway, mobile app, VAT e-invoice, AI analytics. Không implement trong lộ trình trên trừ khi BA/PRD thay đổi.

---

## Ghi chú kỹ thuật đáng chú ý (từ audit)

1. **Envelope không đồng nhất (đã xác nhận bằng code):**
   - `auth.service`, `students`, `users` trả `{ statusCode, message, data, meta }`.
   - `categories.service`, `classes.service`, `leads`, `audit` trả **raw object/mảng**.
   - Hệ quả FE (`apiClient` trả `response` thô, không unwrap): `CategoryManagement`, `CourseManagement`, `ClassDetailsPage`, `AuditLogPage`, `CategoryManagerPage`, `LeadsPage`, `StudentListPage`, `StudentApiDetailPage` đọc `resp.data` (raw); còn `AdminSystemManagementPage`, `ProfilePage`, `AuthScreen` đọc `.data.data` (envelope).
   - **Rủi ro:** nếu đổi 1 module sang envelope sẽ vỡ FE đang ăn raw (và ngược lại). → Khi Phase A/D chạm các module này, **phải kiểm tra đúng nơi FE đọc** (grep `.data.data` vs `.data`) để tránh regression. Đề xuất: tạo helper `unwrap<T>()` trong `apiClient` và migrate FE có kiểm soát, **không đổi backend contract trong cùng PR**.
2. **JWT roles cũ trong token:** role đổi không hiệu lực tới khi đăng nhập lại (JWT 1d). JwtStrategy đã đọc DB lại mỗi request (roles fresh) → OK.
3. **`Student.status` seed mặc định `ACTIVE`**, spec nói bắt đầu từ `Lead` → cần chốt: Lead riêng bảng `Lead`; Student vào là ACTIVE. Vòng đời FR6 map cho `Student`, không phải Lead → làm rõ BA.
4. **Branch chưa có trên Student/Lead/Invoice/Payment** trong schema → **chặn branch isolation**. Cần migration thêm `branchId` trước Phase E.
5. **`classes.service` include `teacher: true`** → trả toàn bộ field `SystemUser`, gồm `passwordHash`, `googleSub` (rủi ro lộ credential). Đã note test 4.1-TC-04 GAP; fix bằng `select` public field / `toPublicUser`. **Ưu tiên Phase B5.**

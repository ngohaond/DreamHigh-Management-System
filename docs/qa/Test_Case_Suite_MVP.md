# Bộ Test Case Toàn Bộ Nghiệp Vụ — DreamHigh PMS (MVP)

> **Nguồn yêu cầu:** `PRD_QuanLyDaoTao_TrungTamTiengAnh.md`, `_bmad-output/planning-artifacts/epics.md` (FR1–FR20), các story `_bmad-output/implementation-artifacts/1-*` … `5-*`.
> **Nguồn hiện trạng code:** `pms-eng-api/prisma/schema.prisma`, các controller/service trong `pms-eng-api/src/modules`, FE `dreamhigh-web/src`.
> **Ngày lập:** theo trạng thái repo hiện tại (sprint-status: Epic 1–5 đang in-progress, 1.1/1.2/2.1/2.2 ở *review*).
> **Cách đọc cột "Trạng thái":**
> - `DONE-CODE`: đã có code backend + đã có unit test.
> - `HAS-CODE`: đã có endpoint/service nhưng chưa có test tự động.
> - `GAP`: nghiệp vụ theo spec **chưa có code** (hoặc chỉ mock FE) — test sẽ FAIL nếu chạy, dùng làm acceptance cho lộ trình.
> - `MOCK`: FE đang dùng mock, chưa nối API.

## Quy ước mã test case

`<Epic>.<Story>-TC-<nn>` — ví dụ `3.1-TC-04`. Loại: `Positive | Negative | Boundary | Security | UI | Perf`.
Ưu tiên: `P0` (blocker MVP/tiền/bảo mật), `P1` (luồng chính), `P2` (edge/NFR).

Tầng kiểm thử:
- **Unit (U)**: Jest + ts-jest, mock `PrismaService` (theo pattern `users.service.spec.ts`).
- **Integration (I)**: Nest Testing + PostgreSQL thật (sẽ thiết lập trong Phase 4 của lộ trình).
- **E2E (E)**: Playwright (chưa cấu hình — thuộc roadmap).
- **Manual (M)**: UAT theo persona.

---

## Epic 1 — Thiết lập Hệ thống & Danh mục

### Story 1.1 — Xác thực & Quản lý Tài khoản (FR2 nền tảng)

Endpoint: `POST /api/auth/register`, `POST /api/auth/login`, `POST /api/auth/google`, `GET /api/users/profile`, `PATCH /api/users/change-password`.

| TC ID | Loại | Ưu tiên | Mô tả | Điều kiện / Bước | Kết quả mong đợi | Trace | Trạng thái | Test file |
|---|---|---|---|---|---|---|---|---|
| 1.1-TC-01 | Positive | P1 | Đăng ký tài khoản email hợp lệ | POST register body đủ field | 201, envelope, `data` không có `passwordHash` | `auth.service.register` | HAS-CODE | `auth.service.spec.ts` |
| 1.1-TC-02 | Negative | P1 | Đăng ký trùng email | Email đã tồn tại | 400 "Email đã được sử dụng…" | `register` | HAS-CODE | `auth.service.spec.ts` |
| 1.1-TC-03 | Positive | P0 | Đăng nhập đúng mật khẩu | User ACTIVE, có passwordHash | 200, `accessToken`, `user.roles` | `auth.service.login` | HAS-CODE | `auth.service.spec.ts` |
| 1.1-TC-04 | Negative | P0 | Đăng nhập sai mật khẩu | Mật khẩu sai | 401 "Thông tin đăng nhập không hợp lệ" | `login` | HAS-CODE | `auth.service.spec.ts` |
| 1.1-TC-05 | Negative | P0 | Tài khoản INACTIVE đăng nhập | status ≠ ACTIVE | 401 khóa tài khoản | `login` | HAS-CODE | `auth.service.spec.ts` |
| 1.1-TC-06 | Negative | P1 | Tài khoản chỉ Google, login mật khẩu | passwordHash = null | 401 hướng dẫn dùng Google | `login` | HAS-CODE | `auth.service.spec.ts` |
| 1.1-TC-07 | Security | P0 | Login Google: email chưa verify | `email_verified=false` | 401 | `loginWithGoogle` | HAS-CODE | `auth.service.spec.ts` |
| 1.1-TC-08 | Security | P0 | JWT secret fallback tồn tại | Đọc `auth.module.ts`, `jwt.strategy.ts` | Phải fail-fast khi thiếu `JWT_SECRET` prod; hiện còn fallback `'dreamhigh_super_secret_key_2026'` → **FAIL** | ACTION_PLAN Phase 0 | GAP | (config test) |
| 1.1-TC-09 | Positive | P1 | Đổi mật khẩu đúng mật khẩu cũ | Old đúng, new hợp lệ | 200, hash mới | `users.service.changePassword` | DONE-CODE | `users.service.spec.ts` |
| 1.1-TC-10 | Negative | P1 | Đổi mật khẩu sai mật khẩu cũ | Old sai | 400 | `changePassword` | DONE-CODE | `users.service.spec.ts` |
| 1.1-TC-11 | Security | P0 | JWT payload chứa role & branch cập nhật | Đổi role user, login lại | Token mới phản ánh role | Story 1.3 AC | HAS-CODE | `auth.service.spec.ts` |
| 1.1-TC-12 | Positive | P2 | Đăng nhập Google tạo user mới | Chưa có user với sub | Tạo user role STUDENT | `loginWithGoogle` | HAS-CODE | `auth.service.spec.ts` |

### Story 1.2 — Danh mục Đào tạo & Khóa học (FR1, FR7)

Endpoint: `/api/categories/{programs,levels,class-types,rooms,courses}`.

| TC ID | Loại | Ưu tiên | Mô tả | Bước | Kết quả mong đợi | Trace | Trạng thái | Test file |
|---|---|---|---|---|---|---|---|---|
| 1.2-TC-01 | Positive | P1 | Chuẩn hóa mã/tên (trim, khoảng trắng) | Gọi `normalizeCatalogCode` | Mã chuẩn hóa | `catalog-normalize.ts` | DONE-CODE | `catalog-normalize.spec.ts` |
| 1.2-TC-02 | Positive | P1 | Tạo program → conflict nếu trùng code | create 2 lần cùng code | 1 OK, 1 Conflict 409 | `createProgram` | HAS-CODE | `categories.service.spec.ts` |
| 1.2-TC-03 | Negative | P1 | Program thiếu code/name | POST thiếu field | 400 | `createProgram` | HAS-CODE | cùng file |
| 1.2-TC-04 | Positive | P1 | Soft-delete program lan sang level | delete program có levels | Program & levels INACTIVE | `softDeleteProgram` | HAS-CODE | cùng file |
| 1.2-TC-05 | Boundary | P1 | Tạo level sortOrder không phải số | sortOrder="abc" | sortOrder = 0 | `createLevel` | HAS-CODE | cùng file |
| 1.2-TC-06 | Negative | P0 | Soft-delete room còn session sắp tới | room có session tương lai | 400 chặn | `softDeleteRoom` | HAS-CODE | cùng file |
| 1.2-TC-07 | Negative | P0 | Soft-delete course còn lớp PLANNED/ACTIVE | Có lớp liên kết | 400 chặn | `softDeleteCourse` | HAS-CODE | cùng file |
| 1.2-TC-08 | Boundary | P2 | findCourses phân trang + search + levelId | page=2, limit=5, search | `meta.total/page/limit/totalPages` đúng; limit ≤ 100 | `findCourses` | HAS-CODE | cùng file |
| 1.2-TC-09 | Negative | P0 | Payload field lạ vào create course | Body có `id`, `level` relation | Bị whitelist chặn | ACTION_PLAN Phase 1 | GAP | (DTO test) |
| 1.2-TC-10 | Security | P1 | TEACHER/STAFF gọi POST program | Token không đủ role | 403 | `categories.controller` roles | HAS-CODE | (guard) |

### Story 1.3 — IAM & RBAC đa vai trò / đa chi nhánh (FR2, FR3)

Endpoint: `GET/POST /api/users`, `PATCH /api/users/:id`, `PATCH /api/users/:id/roles`, `GET /api/users/lookup/roles`.

| TC ID | Loại | Ưu tiên | Mô tả | Bước | Kết quả mong đợi | Trace | Trạng thái | Test file |
|---|---|---|---|---|---|---|---|---|
| 1.3-TC-01 | Positive | P1 | Admin tạo user đa role + đa branch | POST /users đủ field | 201, badge roles/branches đúng | `users.service.createUser` | HAS-CODE | `users.service.spec.ts` |
| 1.3-TC-02 | Negative | P0 | Tạo user với role không tồn tại | roles: ["HACKER"] | 400 | `createUser` | HAS-CODE | cùng file |
| 1.3-TC-03 | Negative | P0 | Tạo user với branchId không tồn tại | branchIds: [999] | 400 | `createUser` | HAS-CODE | cùng file |
| 1.3-TC-04 | Negative | P1 | Trùng username/email | POST trùng | 409 Conflict | `users.service` | HAS-CODE | cùng file |
| 1.3-TC-05 | Positive | P1 | Update roles thay thế hoàn toàn | PATCH :id/roles | Xóa cũ, tạo mới trong transaction | `updateUser` | HAS-CODE | cùng file |
| 1.3-TC-06 | Security | P0 | STAFF/MANAGER gọi GET /users | Token không ADMIN | 403 | `users.controller` | HAS-CODE | (guard) |
| 1.3-TC-07 | Positive | P1 | Toggle ACTIVE ↔ INACTIVE | PATCH status | Trạng thái đúng, không tự khóa mình (UI) | Story 1.3 AC2 | HAS-CODE | (UI M) |
| 1.3-TC-08 | Security | P0 | Super Admin matrix read-only | FE tab Roles | Không sửa được quyền ADMIN | Story 1.3 note | MOCK | (UI M) |

### Story 1.4 — Audit Log (FR4)

Endpoint: `GET /api/audit-logs` (ADMIN). Interceptor: `common/interceptors/audit.interceptor.ts`.

| TC ID | Loại | Ưu tiên | Mô tả | Bước | Kết quả mong đợi | Trace | Trạng thái | Test file |
|---|---|---|---|---|---|---|---|---|
| 1.4-TC-01 | Positive | P0 | POST tạo bản ghi audit | Gọi 1 endpoint POST thành công | `AuditLog` có userId/action/resource/ip | `audit.interceptor` | HAS-CODE | `audit.interceptor.spec.ts` |
| 1.4-TC-02 | Positive | P0 | PATCH/DELETE ghi recordId từ URL | Gọi PATCH /students/5 | recordId="5" | `audit.interceptor` | HAS-CODE | cùng file |
| 1.4-TC-03 | Security | P0 | Password/token bị lọc khỏi details | Body có password, access_token | Không xuất hiện trong `details` | `safeBody` filter | HAS-CODE | cùng file |
| 1.4-TC-04 | Negative | P1 | Request lỗi (4xx/5xx) không ghi audit | Gọi POST lỗi | Không tạo audit | `tap` chỉ chạy success | HAS-CODE | cùng file |
| 1.4-TC-05 | Security | P1 | STAFF gọi GET /audit-logs | Token STAFF | 403 | `audit.controller` | HAS-CODE | (guard) |
| 1.4-TC-06 | Security | P2 | Lỗi ghi audit không chặn response | Prisma audit throw | Response vẫn 2xx | `catch` trong interceptor | HAS-CODE | cùng file |
| 1.4-TC-07 | Boundary | P1 | `tap(async …)` không await → unhandled | Code review | Cần chờ promise / `concatMap` | ACTION_PLAN Phase 4 | GAP | (refactor) |

---

## Epic 2 — Tuyển sinh & Vòng đời Học viên

### Story 2.1 — Hồ sơ & Tìm kiếm Học viên (FR5)

Endpoint: `GET /api/students`, `POST /api/students`, `GET /api/students/:id`, `PATCH /api/students/:id`, `DELETE /api/students/:id`, `GET /api/students/parents`.

| TC ID | Loại | Ưu tiên | Mô tả | Bước | Kết quả mong đợi | Trace | Trạng thái | Test file |
|---|---|---|---|---|---|---|---|---|
| 2.1-TC-01 | Positive | P1 | Tạo học viên hợp lệ | POST đủ field + parent | 201, `parent` trả về | `students.service.create` | HAS-CODE | `students.service.spec.ts` |
| 2.1-TC-02 | Negative | P0 | Trùng SĐT phụ huynh | Parent phone đã tồn tại | 409 + `existingParentId` | `create` | HAS-CODE | cùng file |
| 2.1-TC-03 | Negative | P0 | Trùng SĐT học viên | Student phone đã tồn tại | 409 + `existingStudentId` | `create` | HAS-CODE | cùng file |
| 2.1-TC-04 | Positive | P1 | Chuẩn hóa SĐT (bỏ khoảng trắng) | phone "090 123 4567" | Lưu "0901234567" | `normalizePhone` | HAS-CODE | cùng file |
| 2.1-TC-05 | Positive | P1 | Search theo tên/mã/SĐT/PH | GET ?search= | Lọc đúng OR | `findAll` | HAS-CODE | cùng file |
| 2.1-TC-06 | Negative | P0 | Mass assignment field lạ | POST có `id`, `createdAt` | Bị reject/whitelist | ACTION_PLAN Phase 1 | GAP | (DTO) |
| 2.1-TC-07 | Security | P0 | IDOR: đọc student branch khác | Token branch A gọi student branch B | 403/404 | ACTION_PLAN Phase 1 | GAP | (integration) |
| 2.1-TC-08 | UI | P2 | Search debounce < 2s (NFR2) | Gõ từ khóa | < 2000ms render | NFR2 | MOCK | (E2E) |

### Story 2.2 — Trạng thái lộ trình (FR6)

Endpoint: `PATCH /api/students/:id/status`. State machine: `students/state-machine/student-status.machine.ts`.

| TC ID | Loại | Ưu tiên | Mô tả | Bước | Kết quả mong đợi | Trace | Trạng thái | Test file |
|---|---|---|---|---|---|---|---|---|
| 2.2-TC-01 | Positive | P0 | ACTIVE → GRADUATED | PATCH status | 200, history ghi from/to | `updateStatus` | HAS-CODE | `students.service.spec.ts` |
| 2.2-TC-02 | Negative | P0 | RESERVED → GRADUATED bị chặn | PATCH | 400 message rõ | machine | DONE-CODE | `student-status.machine.spec.ts` |
| 2.2-TC-03 | Negative | P1 | Trạng thái không đổi (from = to) | PATCH cùng trạng thái | 400 | `updateStatus` | HAS-CODE | `students.service.spec.ts` |
| 2.2-TC-04 | Positive | P1 | Ghi `statusChangedAt` + history trong transaction | Transition hợp lệ | 2 thao tác atomic | `$transaction` | HAS-CODE | cùng file |
| 2.2-TC-05 | Negative | P0 | Gửi `status` qua PATCH /students/:id | Body có status | 400 yêu cầu dùng endpoint status | `update` | HAS-CODE | cùng file |
| 2.2-TC-06 | Positive | P1 | DELETE student = chuyển DROPPED | DELETE :id | status DROPPED, không xóa cứng | `delete` | HAS-CODE | cùng file |
| 2.2-TC-07 | Boundary | P2 | GRADUATED không có transition nào | getAllowedTargets | `[]` | machine | DONE-CODE | machine spec |
| 2.2-TC-08 | UI | P2 | Modal bắt lý do cho transition nhạy cảm | FE đổi Sang Bảo lưu | Bắt buộc lý do | Story 2.2 AC3 | HAS-CODE | (UI M) |

### Story 2.3 — Placement Test & gợi ý cấp độ (FR12)

Endpoint: `POST /api/enrollment/placement-test`, `POST /api/enrollment/leads/:id/convert`.

| TC ID | Loại | Ưu tiên | Mô tả | Bước | Kết quả mong đợi | Trace | Trạng thái | Test file |
|---|---|---|---|---|---|---|---|---|
| 2.3-TC-01 | Positive | P1 | Convert Lead → Student + Parent | POST convert lead mới | Student ACTIVE, lead CONVERTED, link student | `enrollment.service.convertLeadToStudent` | HAS-CODE | `enrollment.service.spec.ts` |
| 2.3-TC-02 | Negative | P0 | Convert lead đã CONVERTED | Gọi lần 2 | 400 | `convertLeadToStudent` | HAS-CODE | cùng file |
| 2.3-TC-03 | Positive | P1 | Tái sử dụng Parent theo SĐT | Parent đã tồn tại cùng phone | Không tạo trùng | `convertLeadToStudent` | HAS-CODE | cùng file |
| 2.3-TC-04 | Boundary | P1 | Barem: total > 80 → L4 | listening+reading+writing | suggestedLevelCode="L4" | `recordPlacementTest` | HAS-CODE | `enrollment.service.spec.ts` |
| 2.3-TC-05 | Boundary | P1 | Barem: total ≤ 40 → L1 | Điểm thấp | "L1" | `recordPlacementTest` | HAS-CODE | cùng file |
| 2.3-TC-06 | Positive | P1 | Lưu placement + recommendedLevelId | POST placement | Có bản ghi DB + level gợi ý | Story 2.3 AC5 | GAP | (schema thiếu `PlacementTest`) |
| 2.3-TC-07 | Negative | P0 | Map theo bảng Level cấu hình (không hardcode) | Đổi barem | Gợi ý đổi theo cấu hình | Story 2.3 AC3 | GAP | — |

---

## Epic 3 — Điều phối Thời khóa biểu & Lịch dạy

### Story 3.1 — Xếp lịch lớp học & chặn trùng (FR8)

| TC ID | Loại | Ưu tiên | Mô tả | Bước | Kết quả mong đợi | Trace | Trạng thái | Test file |
|---|---|---|---|---|---|---|---|---|
| 3.1-TC-01 | Positive | P0 | Tạo lớp + sinh sessions trong transaction | POST class có schedule | Class + N sessions tạo thành công | Story 3.1 AC1 | GAP | `schedule.service.spec.ts` (mới) |
| 3.1-TC-02 | Negative | P0 | Trùng giáo viên cùng khung giờ | GV đã có session overlap | 422/400 + tên GV | Story 3.1 AC2 | GAP | `conflict.util.spec.ts` (mới) |
| 3.1-TC-03 | Negative | P0 | Trùng phòng cùng khung giờ | Room overlap | 422/400 + tên phòng | Story 3.1 AC2 | GAP | cùng file |
| 3.1-TC-04 | Boundary | P1 | Biên overlap: end == start | new_start == existing_end | KHÔNG tính trùng | Story 3.1 AC3 | GAP | `conflict.util.spec.ts` |
| 3.1-TC-05 | Boundary | P1 | Biên overlap: chồng 1 phút | new_start < existing_end | Tính trùng | Story 3.1 AC3 | GAP | cùng file |
| 3.1-TC-06 | Negative | P1 | Sĩ số lớp > sức chứa phòng | maxStudents > room.capacity | 400 (cần quyết định BA) | (cần chốt) | GAP | — |
| 3.1-TC-07 | Positive | P1 | Soft-delete room/course guard chặn khi có lớp | Đã có test ở 1.2-TC-06/07 | 400 | `categories.service` | HAS-CODE | `categories.service.spec.ts` |

### Story 3.2 — Dời lịch & đổi giáo viên/phòng (FR9)

| TC ID | Loại | Ưu tiên | Mô tả | Bước | Kết quả mong đợi | Trace | Trạng thái | Test file |
|---|---|---|---|---|---|---|---|---|
| 3.2-TC-01 | Positive | P0 | Dời 1 session, các session sau tịnh tiến | PATCH reschedule | Sessions sau dời cùng delta | Story 3.2 AC | GAP | `schedule.service.spec.ts` |
| 3.2-TC-02 | Positive | P0 | Đổi giáo viên cho 1 session | PATCH teacher | Session dùng GV mới, không đổi class | Story 3.2 AC | GAP | cùng file |
| 3.2-TC-03 | Negative | P0 | Dời vào khung GV bận | Target overlap | 422/400 | Story 3.2 | GAP | cùng file |
| 3.2-TC-04 | Positive | P1 | Lưu lịch sử thay đổi lịch | Sau reschedule | Có audit/change log | ACTION_PLAN Phase 2.3 | GAP | — |

### Story 3.3 — TKB cá nhân giáo viên (FR10)

| TC ID | Loại | Ưu tiên | Mô tả | Bước | Kết quả mong đợi | Trace | Trạng thái | Test file |
|---|---|---|---|---|---|---|---|---|
| 3.3-TC-01 | Positive | P0 | GV xem session của mình | `GET /sessions/my-schedule` | Chỉ session teacherId = current | Story 3.3 AC | GAP | `sessions.service.spec.ts` (mới) |
| 3.3-TC-02 | Security | P0 | GV không xem session GV khác | Query teacherId khác | Bị loại / 403 | NFR5 | GAP | cùng file |
| 3.3-TC-03 | UI | P1 | Widget calendar trên dashboard | GV login | Hiển thị session sắp tới | Story 3.3 AC | MOCK | (UI M) |

### Story 3.4 — Thống kê giờ dạy (FR11)

| TC ID | Loại | Ưu tiên | Mô tả | Bước | Kết quả mong đợi | Trace | Trạng thái | Test file |
|---|---|---|---|---|---|---|---|---|
| 3.4-TC-01 | Positive | P0 | Tổng giờ dạy theo tháng/GV | `GET /reports/teaching-hours` | Σ(end-start) session đã diễn ra | Story 3.4 AC | GAP | `teaching-hours.service.spec.ts` |
| 3.4-TC-02 | Boundary | P1 | Session CANCELLED/RESCHEDULED không tính | Có session hủy | Không cộng giờ | Story 3.4 AC | GAP | cùng file |
| 3.4-TC-03 | Boundary | P1 | Session tương lai không tính | end > now | Loại khỏi tổng | (chốt BA) | GAP | — |

---

## Epic 4 — Vận hành học thuật tại lớp

### Story 4.1 — Xem chi tiết lớp (FR yêu cầu nền)

Endpoint: `GET /api/classes/:code`.

| TC ID | Loại | Ưu tiên | Mô tả | Bước | Kết quả mong đợi | Trace | Trạng thái | Test file |
|---|---|---|---|---|---|---|---|---|
| 4.1-TC-01 | Positive | P1 | Lấy chi tiết lớp theo mã | GET /classes/PY-K1-01 | Đủ course/teacher/sessions/enrollments/exams | `classes.service.getClassDetails` | HAS-CODE | `classes.service.spec.ts` |
| 4.1-TC-02 | Negative | P1 | Mã lớp không tồn tại | GET /classes/XXXX | 404 | `getClassDetails` | HAS-CODE | cùng file |
| 4.1-TC-03 | Security | P0 | Teacher lớp khác xem chi tiết | Token GV không dạy lớp | 403 | NFR5 | GAP | — |
| 4.1-TC-04 | Security | P0 | Rò `passwordHash` qua teacher include | GET details | `teacher` chỉ field public | to-public-user | GAP | cùng file |

### Story 4.2 — Điểm danh (FR13)

| TC ID | Loại | Ưu tiên | Mô tả | Bước | Kết quả mong đợi | Trace | Trạng thái | Test file |
|---|---|---|---|---|---|---|---|---|
| 4.2-TC-01 | Positive | P0 | Lưu bulk điểm danh 1 session | POST attendance bulk | Mọi record upsert đúng | Story 4.2 AC3 | GAP | `attendance.service.spec.ts` (mới) |
| 4.2-TC-02 | Negative | P0 | Học viên không thuộc lớp | Chèn student ngoài enrollment | 400/422 | Story 4.2 | GAP | cùng file |
| 4.2-TC-03 | Positive | P1 | Cập nhật lại điểm danh cùng (sessionId, studentId) | Chạy 2 lần | Upsert không nhân bản | unique constraint | GAP | cùng file |
| 4.2-TC-04 | Security | P0 | GV không phụ trách sửa điểm danh | Token GV khác | 403 | Story 4.2 AC4 | GAP | cùng file |
| 4.2-TC-05 | Boundary | P2 | Session CANCELLED không cho điểm danh | Session status CANCELLED | 400 | (chốt BA) | GAP | — |

### Story 4.3 — Nhập bảng điểm (FR15)

| TC ID | Loại | Ưu tiên | Mô tả | Bước | Kết quả mong đợi | Trace | Trạng thái | Test file |
|---|---|---|---|---|---|---|---|---|
| 4.3-TC-01 | Positive | P0 | Nhập grade + remarks theo exam | Bulk POST grade | Lưu đúng score/remarks | Story 4.3 AC4 | GAP | `grade.service.spec.ts` (mới) |
| 4.3-TC-02 | Negative | P0 | Score ngoài [0, maxScore] | score = maxScore+1 | 400 | Story 4.3 AC2 | GAP | cùng file |
| 4.3-TC-03 | Boundary | P2 | Cảnh báo điểm thấp dưới ngưỡng | score < threshold | Trả flag/banner | Story 4.3 AC3 | GAP | — |
| 4.3-TC-04 | Negative | P0 | Tổng weight exam ≠ 100% | Cấu hình weight sai | Cảnh báo/400 | ACTION_PLAN 2.5 | GAP | — |

### Story 4.4 — Cảnh báo chuyên cần (FR14)

| TC ID | Loại | Ưu tiên | Mô tả | Bước | Kết quả mong đợi | Trace | Trạng thái | Test file |
|---|---|---|---|---|---|---|---|---|
| 4.4-TC-01 | Positive | P0 | Vắng 3 buổi liên tiếp → cảnh báo | Sinh attendance vắng x3 | Tạo alert risk | Story 4.4 AC1-3 | GAP | `attendance-risk.service.spec.ts` |
| 4.4-TC-02 | Boundary | P1 | Vắng 2 buổi → không cảnh báo | 2 vắng | Không alert | ngưỡng = 3 | GAP | cùng file |
| 4.4-TC-03 | Boundary | P1 | Chuỗi vắng bị reset khi có Present | Vắng, vắng, Present, vắng | Không alert | quy tắc chuỗi | GAP | cùng file |
| 4.4-TC-04 | Boundary | P2 | Absent có phép có tính không | ABSENT_EXCUSED | Theo quyết định BA | Story 4.4 AC2 | GAP | — |
| 4.4-TC-05 | Positive | P1 | API danh sách HV nguy cơ | GET /alerts/attendance-risk | Danh sách đúng + badge đỏ | Story 4.4 AC6 | GAP | — |

---

## Epic 5 — Học phí & Công nợ

### Story 5.1 — Khung học phí gốc (FR16)

| TC ID | Loại | Ưu tiên | Mô tả | Bước | Kết quả mong đợi | Trace | Trạng thái | Test file |
|---|---|---|---|---|---|---|---|---|
| 5.1-TC-01 | Positive | P0 | Tạo fee plan theo course | POST fee plan | Lưu VND, hiệu lực | Story 5.1 AC1-2 | GAP | `fee-plan.service.spec.ts` |
| 5.1-TC-02 | Negative | P1 | Số tiền âm | amount < 0 | 400 | Story 5.1 AC4 | GAP | cùng file |
| 5.1-TC-03 | Positive | P1 | Soft deactivate không phá hóa đơn cũ | Deactivate plan đã dùng | Hóa đơn cũ giữ giá | Story 5.1 AC3 | GAP | cùng file |

### Story 5.2 — Ưu đãi / cấn trừ (FR17)

| TC ID | Loại | Ưu tiên | Mô tả | Bước | Kết quả mong đợi | Trace | Trạng thái | Test file |
|---|---|---|---|---|---|---|---|---|
| 5.2-TC-01 | Positive | P0 | Giảm % | base 1.000.000, 10% | amountDue 900.000 | Story 5.2 AC4 | GAP | `discount.util.spec.ts` |
| 5.2-TC-02 | Positive | P0 | Giảm fix amount | base 1.000.000, -100.000 | 900.000 | Story 5.2 AC1 | GAP | cùng file |
| 5.2-TC-03 | Negative | P0 | Giảm vượt số phải thu | discount > base | Clamp = base / 400 | Story 5.2 AC1 | GAP | cùng file |
| 5.2-TC-04 | Boundary | P1 | Kết hợp % + fix (thứ tự) | 10% + 50.000 | Theo quy tắc chốt BA | Story 5.2 AC4 | GAP | — |

### Story 5.3 — Ghi nhận thu tiền & công nợ (FR18)

| TC ID | Loại | Ưu tiên | Mô tả | Bước | Kết quả mong đợi | Trace | Trạng thái | Test file |
|---|---|---|---|---|---|---|---|---|
| 5.3-TC-01 | Positive | P0 | Thu 1 phần → PARTIAL | invoice 1.000.000, thu 400.000 | status PARTIAL, outstanding 600.000 | Story 5.3 AC2 | GAP | `invoice.service.spec.ts` |
| 5.3-TC-02 | Positive | P0 | Thu đủ → COMPLETED | Thu đủ số còn lại | status COMPLETED, outstanding 0 | Story 5.3 AC2 | GAP | cùng file |
| 5.3-TC-03 | Negative | P0 | Thu vượt số nợ | Thu > outstanding | 400 (chốt BA) | Story 5.3 | GAP | cùng file |
| 5.3-TC-04 | Negative | P0 | Idempotency transactionRef trùng | 2 payment cùng externalRef | Chỉ ghi 1 | Story 5.3 AC3 | GAP | cùng file |
| 5.3-TC-05 | Boundary | P0 | Lỗi giữa transaction → rollback | Payment create lỗi sau ghi ledger | Không có payment mồ côi | Story 5.3 test | GAP | cùng file |
| 5.3-TC-06 | Positive | P1 | Emit PaymentSuccessEvent | Thu thành công | Event được phát | Story 5.3 AC5 | GAP | — |

### Story 5.4 — Phiếu thu PDF (FR19)

| TC ID | Loại | Ưu tiên | Mô tả | Bước | Kết quả mong đợi | Trace | Trạng thái | Test file |
|---|---|---|---|---|---|---|---|---|
| 5.4-TC-01 | Positive | P0 | Xuất PDF có đủ trường | GET receipt | số phiếu, ngày, HV, số tiền, phương thức, người lập | Story 5.4 | GAP | `receipt.service.spec.ts` |
| 5.4-TC-02 | UI | P1 | Font tiếng Việt in đúng | Render PDF | Dấu tiếng Việt không lỗi | ACTION_PLAN Phase 3 | GAP | (manual) |
| 5.4-TC-03 | Security | P0 | Không xuất receipt payment branch khác | Token branch A | 403 | NFR5 | GAP | — |

### Story 5.5 — Dashboard nợ học phí (FR20)

| TC ID | Loại | Ưu tiên | Mô tả | Bước | Kết quả mong đợi | Trace | Trạng thái | Test file |
|---|---|---|---|---|---|---|---|---|
| 5.5-TC-01 | Positive | P0 | Tổng nợ / số HV nợ / quá hạn | GET /reports/arrears | Chỉ số khớp dữ liệu | Story 5.5 AC1 | GAP | `arrears.service.spec.ts` |
| 5.5-TC-02 | Security | P0 | Filter branch isolation | Manager branch A | Không thấy nợ branch B | Story 5.5 AC4 | GAP | cùng file |
| 5.5-TC-03 | Boundary | P1 | Phân loại Đúng hạn / Quá hạn theo dueDate | dueDate < now | Status Quá hạn | Story 5.5 AC2 | GAP | cùng file |
| 5.5-TC-04 | UI | P2 | Export Excel nợ (NFR3) | Nút export | File .xlsx đúng | NFR3 | GAP | — |

---

## Ma trận phủ (traceability)

| FR | Story | Test case (số lượng) | Đã có code + test | GAP |
|---|---|---|---|---|
| FR1 | 1.2 | 10 | 8 (cần gen) | DTO 1.2-TC-09 |
| FR2 | 1.1, 1.3 | 8 + 8 | Partial | DTO/whitelist |
| FR3 | 1.3 | (trong 1.3) | Partial | Branch isolation |
| FR4 | 1.4 | 7 | 6 (cần gen) | tap await |
| FR5 | 2.1 | 8 | 5 (cần gen) | IDOR, DTO |
| FR6 | 2.2 | 8 | 5 (cần gen) | — |
| FR7 | 1.2 | (trong 1.2) | Course CRUD ✅ | — |
| FR8 | 3.1 | 7 | 1 | 6 GAP (module Schedule) |
| FR9 | 3.2 | 4 | 0 | 4 GAP |
| FR10 | 3.3 | 3 | 0 | 3 GAP |
| FR11 | 3.4 | 3 | 0 | 3 GAP |
| FR12 | 2.3 | 7 | 5 (cần gen) | PlacementTest schema |
| FR13 | 4.2 | 5 | 0 | 5 GAP |
| FR14 | 4.4 | 5 | 0 | 5 GAP |
| FR15 | 4.3 | 4 | 0 | 4 GAP |
| FR16 | 5.1 | 3 | 0 | 3 GAP |
| FR17 | 5.2 | 4 | 0 | 4 GAP |
| FR18 | 5.3 | 6 | 0 | 6 GAP |
| FR19 | 5.4 | 3 | 0 | 3 GAP |
| FR20 | 5.5 | 4 | 0 | 4 GAP (+Finance module chưa có) |

**Tổng: 109 test case.** Đã có code backend: 44 (8 DONE-CODE + 36 HAS-CODE). GAP: 65 (chủ yếu Epic 3–5).

---

## Test xuyên suốt (cross-cutting / NFR)

| TC ID | Loại | Ưu tiên | Mô tả | Trạng thái |
|---|---|---|---|---|
| X-TC-01 | Security | P0 | Mọi mutation chính dùng DTO, `forbidNonWhitelisted: true` | GAP (main.ts chưa bật) |
| X-TC-02 | Security | P0 | Envelope chuẩn `{ statusCode, message, data, meta }` toàn API | GAP (discrepancy categories/classes) |
| X-TC-03 | Security | P0 | Branch isolation test integration PostgreSQL | GAP |
| X-TC-04 | Security | P0 | Không trả `passwordHash`, `googleSub`, raw Prisma error | Partial (to-public-user) |
| X-TC-05 | Security | P0 | Rate limit login/register | GAP |
| X-TC-06 | Perf | P2 | 10.000 HV vẫn < 2s grid, < 5s report | GAP |
| X-TC-07 | UI | P1 | Responsive tablet cho Attendance, CRM, Admin | GAP |
| X-TC-08 | Security | P1 | Idle timeout 30 phút (NFR6) | GAP |

---

## Ghi chú traceability

- Cột **Test file** đề xuất theo cấu trúc có sẵn `*.spec.ts` cùng thư mục module (pattern `users.service.spec.ts`).
- Một số test (integration/E2E) chưa thể chạy vì chưa cấu hình PostgreSQL test / Playwright — thuộc Phase 4 lộ trình.
- Test case đánh `GAP` là điều kiện chấp nhận (acceptance) cho story tương ứng trong `docs/qa/Development_Roadmap_MVP.md`.

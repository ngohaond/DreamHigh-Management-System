# DEV Guide — Phase B: Scheduling & Sessions

## 1. Mục tiêu

Hoàn thiện nghiệp vụ điều phối lớp học và buổi học (Epic 3, FR8–FR11) bằng dữ liệu thật, thay các màn hình lịch/lớp đang dùng mock. Phase B cho phép quản lý tạo lớp theo khóa và lịch lặp, sinh các buổi học, phát hiện xung đột giáo viên/phòng, xử lý thay đổi lịch, cho giáo viên xem lịch cá nhân và tổng hợp giờ dạy.

**Phạm vi:** backend B1–B5 và frontend B6 trong [Development_Roadmap_MVP.md](Development_Roadmap_MVP.md). Bao gồm Stories 3.1–3.4 và phần mở rộng lớp của Story 4.1. Không bao gồm điểm danh, cảnh báo chuyên cần, nhập điểm hay tài chính (Phase C/D).

## 2. Hiện trạng đã xác nhận trong repo

- Prisma đã có `TrainingClass`, `Session`, `Room`, `Course`, `Branch`, `SystemUser`; bảng DB `sessions` tồn tại.
- `Session` hiện có `classId`, `roomId`, `startTime`, `endTime`, `status` (`NORMAL | RESCHEDULED | CANCELLED`), `topicNote`; index hiện có trên `classId`, `roomId`, `startTime`.
- `TrainingClass` đã có `courseId`, `branchId`, `teacherId`, `classCode`, `maxStudents`, `startDate`, `endDate`, `status` (`PLANNED | ACTIVE | COMPLETED | CANCELLED`).
- `ClassesService` hiện chỉ có `getClassDetails(classCode)`; controller hiện chỉ expose `GET /classes/:code`. Đã có `classes.service.spec.ts` phủ 4.1-TC-01/02/04.
- Chưa có module Schedule/Sessions, conflict utility, API sinh lịch/dời lịch/lịch giáo viên/giờ dạy, hoặc test chuyên biệt cho Phase B.
- `dreamhigh-web/src/pages/Classes/ClassScheduleManagement.tsx` đang đọc từ `MOCK_CLASSES`, `MOCK_ROOMS`, `MOCK_SESSIONS`, `MOCK_TEACHERS`; `ClassModal.tsx`, `SessionActionModal.tsx` là UI liên quan.
- Chi tiết lớp đang trả các quan hệ sessions/exams/enrollments; teacher phải map qua `toPublicUser` để tuyệt đối không lộ `passwordHash`/`googleSub`.

## 3. Tài liệu nguồn và nguyên tắc

Trước khi code, đọc và đối chiếu:

- [Roadmap MVP](Development_Roadmap_MVP.md) — Phase B, B1–B6, DoD.
- [Test Case Suite MVP](Test_Case_Suite_MVP.md) — Epic 3 (3.1–3.4) và Story 4.1.
- `_bmad-output/implementation-artifacts/3-1-xep-lich-lop-hoc.md`
- `_bmad-output/implementation-artifacts/3-2-doi-lich-va-giao-vien.md`
- `_bmad-output/implementation-artifacts/3-3-tra-cuu-tkb-giao-vien.md`
- `_bmad-output/implementation-artifacts/3-4-thong-ke-gio-day.md`
- `ACTION_PLAN_GO_LIVE.md` — Phase 2, đặc biệt mục 2.2–2.3.

Quy tắc phải giữ:

1. Dùng Prisma/NestJS pattern đang có; DTO `class-validator` cho mọi input; response envelope theo convention của endpoint/module được chạm đến. Không đổi contract FE hiện hữu ngoài phạm vi có migration đồng bộ.
2. Auth trước role guard: controller protected dùng `@UseGuards(JwtAuthGuard, RolesGuard)`. Không đăng ký `RolesGuard` global đứng trước JWT guard.
3. Phạm vi tenant/branch được suy ra từ user đã xác thực và dữ liệu lớp/phòng; không tin `branchId`, `teacherId` nhạy cảm do client tự khai nếu server có thể suy ra.
4. Thao tác ghi nhiều bản ghi dùng `prisma.$transaction`; kiểm tra conflict phải chạy lại trong service trước khi ghi, không dựa vào preview ở FE.
5. Dùng `overlaps(aStart, aEnd, bStart, bEnd) = aStart < bEnd && aEnd > bStart`; hai buổi nối tiếp đúng tại biên không conflict.
6. Không trả trực tiếp object `SystemUser` từ Prisma; map `teacher` bằng `toPublicUser` hoặc chỉ select field công khai.
7. Mọi thay đổi phạm vi Phase B phải có unit test cùng module; integration/E2E với DB thật theo hạ tầng hiện có hoặc kế hoạch Phase E.
8. Giữ các sửa lỗi gần đây: `RolesGuard` là controller-scoped sau `JwtAuthGuard`, class detail không được lộ credential. Chạy regression test sau khi sửa các file này.

## 4. Phạm vi triển khai theo thứ tự

### B1 — Schema và migration

1. Kiểm tra `schema.prisma` và migration hiện có trước khi sửa; không tạo lại `Session`/index đã tồn tại.
2. Bổ sung `SessionChange` để lưu lịch sử reschedule/đổi giáo viên/đổi phòng/hủy buổi, tối thiểu gồm:
   - `id`, `sessionId`, `changedBy`, `changeType`, `reason`, `createdAt`;
   - giá trị trước/sau đủ để tái dựng thay đổi (ví dụ `fromStartTime`, `toStartTime`, `fromEndTime`, `toEndTime`, `fromTeacherId`, `toTeacherId`, `fromRoomId`, `toRoomId`, `fromStatus`, `toStatus`). Có thể dùng JSON snapshot nếu migration/typing vẫn truy vấn được; quyết định phải nhất quán và có test.
   - FK đến `Session` và `SystemUser`, index tra cứu theo `sessionId/createdAt`.
3. Teacher hiện nằm ở `TrainingClass.teacherId`, session chưa có `teacherId`. Nếu cần đổi GV cho riêng một session, session phải lưu giảng viên thực dạy riêng (nullable/fallback theo class hoặc backfill rõ ràng); không được cập nhật teacher lớp khiến các buổi khác đổi theo ngoài ý muốn. Nêu rõ lựa chọn trong migration và service.
4. Bổ sung index tổng hợp `(roomId, startTime)` và `(classId, startTime)` chỉ khi schema/DB chưa có index tương đương. Kiểm tra tên bảng mapping thực tế (`classes`, `sessions`).
5. Tạo migration, chạy `prisma format`, `prisma validate`, `prisma generate`; kiểm tra migration áp dụng trên DB test. Không chạy migration phá hủy hoặc reset DB có dữ liệu.

### B2 — Conflict utility

Tạo `pms-eng-api/src/modules/schedule/utils/conflict.util.ts` và `conflict.util.spec.ts`.

- Utility thuần kiểm tra overlap; không phụ thuộc Nest/Prisma.
- Bao gồm test: khoảng không giao nhau, overlap một phần/bao phủ, bằng nhau, `end == start` là không conflict, chồng một phút là conflict.
- Validate `startTime < endTime` tại boundary DTO/service; không cho tạo session thời lượng âm hoặc bằng 0.

### B3 — Schedule service

Tạo module `pms-eng-api/src/modules/schedule/` theo cấu trúc hiện có, gồm DTO, service, controller, module và unit spec.

Các nghiệp vụ bắt buộc:

- **Sinh lịch lớp:** nhận quy tắc lặp (ngày trong tuần, giờ bắt đầu/kết thúc, ngày bắt đầu/kết thúc hoặc số buổi), tạo `TrainingClass` khi cần và các `Session` trong một transaction. Hỗ trợ preview không ghi DB hoặc một hàm tính lịch thuần dùng chung giữa preview/commit. Xác định timezone rõ ràng, không dựa timezone ngầm của máy.
- **Conflict:** kiểm tra giáo viên thực dạy và phòng trên toàn bộ khoảng session mới; bỏ qua session CANCELLED; loại trừ session đang được cập nhật khi reschedule/swap. Conflict response có HTTP 422 (hoặc mã đã thống nhất), mã lỗi ổn định và thông tin tối thiểu: loại tài nguyên, tên GV/phòng, lớp xung đột, khoảng giờ.
- **Reschedule một buổi:** cập nhật giờ bắt đầu/kết thúc, kiểm tra overlap và lưu lịch sử trong cùng transaction.
- **Shift các buổi sau:** khi được yêu cầu, tính delta từ buổi được chọn, giữ duration và khoảng cách tương đối, kiểm tra toàn bộ các session bị ảnh hưởng với nhau và với lịch khác trước khi ghi; nếu một buổi conflict thì rollback cả nhóm.
- **Đổi giáo viên/phòng:** hỗ trợ đổi riêng session; validate tồn tại, trạng thái hoạt động, branch compatibility và conflict. Lưu lịch sử.
- **Trạng thái:** cấm sửa buổi đã hoàn tất; chỉ reschedule buổi hợp lệ theo enum hiện có và quyết định nghiệp vụ. CANCELLED không tham gia conflict/giờ dạy; hủy phải có lý do nếu nghiệp vụ yêu cầu.
- **Lịch cá nhân GV:** chỉ suy ra teacher từ user JWT/quan hệ role; filter theo khoảng thời gian; không nhận teacherId tự do làm cơ sở phân quyền.
- **Giờ dạy:** tổng hợp theo GV và khoảng ngày; không tính session tương lai hoặc CANCELLED; áp dụng đúng định nghĩa “đã dạy” đã thống nhất. Do enum hiện tại chưa có `COMPLETED` cho Session, phải chốt cách xác định buổi hoàn tất (ví dụ `endTime <= now` và không cancelled, hoặc bổ sung trạng thái qua migration) trước khi triển khai, không tự suy diễn.

Unit test tối thiểu: tạo lịch hợp lệ, conflict GV/phòng, biên overlap, transaction rollback khi một buổi trong batch conflict, reschedule đơn, shift nhiều buổi, đổi GV/phòng, buổi cancelled/completed, giờ dạy loại session tương lai/hủy, filter lịch cá nhân theo JWT.

### B4 — API và phân quyền

Các route là đề xuất thống nhất từ roadmap/test suite; kiểm tra prefix `api` và tránh route collision với `GET /classes/:code` hiện có.

| Method + route | Mục đích | Role tối thiểu |
|---|---|---|
| `POST /classes/:id/sessions/preview` | Preview lịch, không ghi DB | ADMIN, MANAGER |
| `POST /classes/:id/sessions/generate` | Sinh và lưu session | ADMIN, MANAGER |
| `PATCH /sessions/:id/reschedule` | Dời buổi/shift các buổi sau | ADMIN, MANAGER |
| `PATCH /sessions/:id/teacher` | Đổi GV của buổi | ADMIN, MANAGER |
| `PATCH /sessions/:id/room` | Đổi phòng | ADMIN, MANAGER |
| `PATCH /sessions/:id/cancel` | Hủy buổi | ADMIN, MANAGER |
| `GET /sessions/my-schedule?from=&to=` | Lịch của giáo viên hiện tại | TEACHER |
| `GET /reports/teaching-hours?from=&to=` | Tổng giờ theo GV | ADMIN, MANAGER, STAFF |

- Mọi endpoint protected có JWT guard trước RolesGuard.
- `my-schedule` không được cho phép đổi scope bằng query `teacherId`; nếu truyền thì reject hoặc bỏ qua nhất quán.
- Kiểm tra branch access từ JWT `branchIds` và branch của class/room/user theo model hiện có; nếu user không có branch phù hợp thì 403/404 theo convention bảo mật của repo.
- DTO phải kiểm tra ISO date/time, ngày bắt đầu/kết thúc, số buổi/weekday, ID integer, giới hạn ngày truy vấn hợp lý và `from < to`.
- Nếu hiện chưa có `@CurrentUser()` decorator, dùng convention request user đang có; không thêm abstraction nếu không cần.

### B5 — Mở rộng ClassesService

Thực hiện trong phạm vi lớp cần cho luồng Phase B:

- `create`, `update`, `list` có filter/pagination cần thiết và `getDetail` (giữ route cũ `GET /classes/:code` để không phá FE hiện tại).
- Validate course/branch/teacher/room tồn tại và trạng thái phù hợp; validate capacity; class code duy nhất; validate lifecycle `PLANNED → ACTIVE → COMPLETED/CANCELLED` theo rule rõ ràng.
- Phân quyền và branch scope; không cho client mass-assign quan hệ/ID tùy ý.
- Teacher response luôn qua `toPublicUser` hoặc `select` allowlist; viết regression test kiểm tra không có `passwordHash`/`googleSub`.
- Không gộp các nghiệp vụ Phase C (attendance/grades) vào service này.

### B6 — Frontend

- Nối `ClassScheduleManagement.tsx`, `ClassModal.tsx`, `SessionActionModal.tsx` và chi tiết lớp với API thật qua `apiClient` + React Query theo pattern FE hiện hữu.
- Loại bỏ dữ liệu mock khỏi luồng đã nối; không xóa mock dùng ở nơi khác nếu còn reference.
- Luồng quản lý: nhập lớp/khóa/GV/chi nhánh/phòng + lịch lặp → preview buổi → hiển thị conflict → xác nhận tạo.
- Luồng biến động: modal đổi giờ/GV/phòng/hủy có xác nhận; hiển thị thông tin tài nguyên/lớp/giờ bị conflict.
- Lịch giáo viên: chỉ hiển thị lịch của user hiện tại; thêm filter tuần/ngày và empty/loading/error/retry states.
- Giờ dạy: bảng theo GV/kỳ; export CSV/Excel chỉ khi thư viện/pattern export đã có hoặc được duyệt trong phạm vi.
- Dùng design system hiện có (`AppLayout`, `PageHeader`, `Card`, `Button`, `Input`), responsive, accessible labels; không tự thêm thư viện UI/calendar trước khi kiểm tra dependencies.

## 5. Test cases và mapping

Bắt buộc đối chiếu cập nhật trạng thái trong `docs/qa/Test_Case_Suite_MVP.md` khi test tương ứng đạt; không đánh dấu DONE chỉ vì endpoint compile.

| Nhóm | Test case |
|---|---|
| Sinh lớp/session | 3.1-TC-01, 3.1-TC-02, 3.1-TC-03 |
| Overlap biên | 3.1-TC-04, 3.1-TC-05 |
| Capacity/room/course guard | 3.1-TC-06, 3.1-TC-07 |
| Reschedule/swap/history | 3.2-TC-01, 3.2-TC-02, 3.2-TC-03, 3.2-TC-04 |
| Lịch GV và scope | 3.3-TC-01, 3.3-TC-02; UI 3.3-TC-03 |
| Giờ dạy | 3.4-TC-01, 3.4-TC-02, 3.4-TC-03 |
| Chi tiết lớp / public teacher | 4.1-TC-01, 4.1-TC-02, 4.1-TC-03, 4.1-TC-04 |

Test mới đề xuất:

- `src/modules/schedule/utils/conflict.util.spec.ts`
- `src/modules/schedule/schedule.service.spec.ts`
- `src/modules/classes/classes.service.spec.ts` — đã có sẵn, phủ 4.1-TC-01/02/04 (4.1-TC-03 còn thiếu vì chưa có scope rule cho teacher xem lớp khác). Bổ sung các case còn thiếu theo khi triển khai B5.
- Controller tests cho RBAC/status code nếu controller có logic riêng.
- E2E với PostgreSQL test database: create → generate → query teacher schedule → reschedule/swap → teaching hours; kiểm tra rollback và branch boundary. Không dùng DB production/developer chứa dữ liệu cá nhân làm fixture test tự động.

### Script kiểm tra nhanh hiện có

`pms-eng-api/e2e-phase-b-check.sh` chạy các kiểm tra auth/RBAC, tồn tại schema `sessions`, và rò credential trong class detail. Script đọc credential từ biến môi trường, không hardcode:

```bash
cd pms-eng-api
ADMIN_EMAIL=... ADMIN_PASSWORD=... PGUSER=... PGPASSWORD=... PGDATABASE=... bash e2e-phase-b-check.sh
```

Khi Phase B có endpoint thật, cập nhật các kỳ vọng `404 (not built)` trong script thành status code đúng và bổ sung luồng generate/reschedule/swap.

## 6. Definition of Done

Phase B chỉ được xem hoàn tất khi:

- [ ] Schema/migration an toàn, Prisma validate/generate pass, migration chạy được trên DB test.
- [ ] B1–B5 backend có DTO, API, auth/RBAC, branch scope, transaction, audit/history theo scope.
- [ ] Conflict detection theo khoảng thời gian đúng; tạo lịch hoặc dời lịch không thể double-booking.
- [ ] Lịch GV được filter server-side theo JWT; không lộ lịch user khác.
- [ ] Giờ dạy có định nghĩa completed rõ ràng, không tính buổi hủy/tương lai.
- [ ] Class detail không lộ `passwordHash` hoặc `googleSub`.
- [ ] Unit tests `conflict.util.spec.ts`, `schedule.service.spec.ts`, `classes.service.spec.ts` pass; integration/E2E cho luồng chính pass.
- [ ] Frontend B6 dùng API thật cho scope đã triển khai; có loading/empty/error/conflict/confirm states; không còn mock trong các luồng đó.
- [ ] Test case suite được cập nhật bằng bằng chứng kiểm thử; không đánh dấu GAP/Manual case thành DONE-CODE nhầm.
- [ ] `npm run build`, `npx jest --runInBand`, `npm run prisma:validate` pass trong `pms-eng-api`; frontend typecheck/build và browser verification pass.
- [ ] Diff được review; không commit/push nếu chưa được yêu cầu.

## 7. Báo cáo DEV sau khi hoàn thành

Báo cáo theo format:

```text
Task: Phase B — Scheduling & Sessions
Phase: B (Epic 3 FR8–FR11; B5 class detail)
Files changed: <liệt kê>
Implementation: <B1–B6 phần đã hoàn thành và phần chưa làm>
Tests run: <lệnh, môi trường, số pass/fail>
Result: <Done / Partial / Blocked; căn cứ DoD>
Remaining risks: <quyết định timezone, completed-session, teacher-per-session, branch scope...>
Next dependency: Phase C attendance/grade; Phase E integration/CI nếu phù hợp
```

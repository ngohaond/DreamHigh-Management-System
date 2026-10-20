# Business Decision Register — DreamHigh MVP

**Phiên bản:** 0.1  
**Ngày ghi nhận:** 19/10/2026  
**Trạng thái:** Baseline nghiệp vụ được người dùng chọn; một số chi tiết triển khai vẫn cần xác nhận  
**Nguồn yêu cầu:** `PRD_QuanLyDaoTao_TrungTamTiengAnh.md` FR-01–FR-20; SRS Module 01/02; các lựa chọn được xác nhận trong phiên làm việc.

> Các lựa chọn bên dưới là baseline được người dùng chấp thuận để đặc tả MVP. Đây không thay thế quy chế tài chính/kế toán hoặc phê duyệt pháp lý của trung tâm. Không triển khai tích hợp ngoài MVP nếu PRD chưa được cập nhật.

## 1. Phạm vi MVP

- Go-Live giữ đầy đủ FR-01–FR-20.
- QBO, SePay, SMS/Zalo, portal học viên/phụ huynh và payment gateway nằm ngoài MVP.
- FR-20 trong MVP giới hạn ở danh sách invoice/học viên còn nợ, danh sách quá hạn và tổng hợp theo chi nhánh/thời gian. Dashboard doanh thu/KPI nâng cao để sau MVP.

## 2. IAM, quyền và chi nhánh

- ADMIN/BGĐ được xem dữ liệu cross-branch.
- MANAGER, STAFF/Học vụ và TEACHER chỉ được xem dữ liệu trong branch được cấp, cùng phạm vi lớp/buổi được phân công đối với giáo viên.
- Backend lấy branch scope từ người dùng đã xác thực; không tin `branchId` client gửi.
- Lead và Student tách biệt; mỗi hồ sơ có `branchId` bắt buộc. Đổi branch là nghiệp vụ riêng, có lý do và audit.
- MANAGER/STAFF được mở khóa attendance; MANAGER/ADMIN được mở khóa grade. Mở khóa cần lý do và audit.

**Chi tiết cần hoàn thiện:** chưa chốt BGĐ dùng role ADMIN hay role DIRECTOR riêng; nếu DIRECTOR riêng thì cần chốt quyền đọc/sửa.

## 3. Lead, Student và Parent

- Lead và Student là entity riêng; chuyển Lead thành Student phải lưu liên kết và audit.
- Tạo hồ sơ chuẩn hóa số điện thoại và cảnh báo nghi trùng. Người có quyền có thể xác nhận tiếp tục; không tự merge hoặc xóa dữ liệu.
- Parent có thể dùng chung khi nghiệp vụ xác nhận đúng người; không tự động gộp Parent.
- Student lifecycle baseline:

```text
ACTIVE ↔ RESERVED
ACTIVE → DROPPED
ACTIVE → GRADUATED
RESERVED → ACTIVE
```

- Không cho phép `RESERVED → GRADUATED` trực tiếp.
- Chuyển trạng thái cần người thực hiện, thời điểm, lý do và lịch sử audit.
- Khi chuyển `RESERVED` hoặc `DROPPED`, không tự xóa enrollment, không tự hủy invoice, không tự hoàn tiền và không tự xóa công nợ.

## 4. Course, Syllabus, Class và enrollment

- Syllabus bắt buộc trước khi Course chuyển sang trạng thái đang học.
- Không thay Syllabus sau khi Course đã bắt đầu; cần chuẩn hóa định nghĩa “bắt đầu” và state “Đang mở” so với SRS.
- Syllabus gốc không bị cập nhật bởi diễn biến thực tế của Course.
- Khi tạo lớp/ghi danh, bắt buộc kiểm tra capacity, duplicate enrollment, xung đột giáo viên/phòng/chi nhánh theo khoảng thời gian.
- Chuyển lớp cần lý do, thời điểm hiệu lực, người thực hiện và audit.

## 5. Attendance

- Các trạng thái: `PRESENT`, `ABSENT_EXCUSED`, `ABSENT_UNEXCUSED`.
- Teacher nhập attendance; attendance khóa theo session.
- MANAGER/STAFF được mở khóa có lý do và audit.
- Cảnh báo khi vắng không phép từ 2 buổi liên tiếp; vắng có phép không tạo chuỗi cảnh báo.
- Không ghi attendance cho học viên không thuộc lớp; session bị hủy không có attendance hợp lệ.

## 6. Exam, Grade và feedback

- Điểm nằm trong khoảng `0..maxScore`.
- Tổng `weightPercent` của các exam trong một lớp không vượt 100%.
- Teacher nhập điểm/nhận xét trước khi exam bị khóa.
- MANAGER/ADMIN mở khóa với lý do và audit.
- Thay đổi điểm cần lưu lịch sử before/after.

## 7. Giờ dạy giáo viên

- Chỉ session `COMPLETED` được tính giờ; session hủy không tính.
- Session dời lịch tính một lần theo session hoàn thành cuối cùng.
- Giáo viên thay phải lưu teacher thực tế; ngoại lệ cần Manager duyệt.
- Session thiếu trạng thái/thời gian hợp lệ bị loại khỏi tổng hợp và phải xử lý trước khi chốt kỳ giờ dạy.

## 8. Invoice, discount và payment

### Invoice và công nợ

- Invoice phải có `dueDate` trước khi chốt.
- Trạng thái invoice: `PENDING`, `PARTIAL`, `COMPLETED`.
- Invoice quá hạn nếu đã qua `dueDate` và `outstanding > 0`.

### Discount

- Mỗi invoice tối đa một discount: phần trăm hoặc số tiền cố định.
- Discount tính trên học phí gốc, không vượt học phí gốc.
- Lưu snapshot discount tại thời điểm tạo invoice; thay đổi học phí course không làm đổi invoice cũ.

### Payment

- Payment đã ghi nhận là append-only; không sửa/xóa payment gốc.
- Sai sót xử lý bằng adjustment/refund record riêng, có quyền và audit.
- Chỉ ADMIN/MANAGER được tạo adjustment/refund.
- Tổng refund không vượt số tiền đã thu trừ refund trước đó.
- Phương thức MVP: `CASH`, `BANK_TRANSFER`.
- Payment cần transaction và idempotency để tránh ghi nhận trùng.

## 9. Audit và phiếu thu

Audit ghi nhận create/update/delete, lock/unlock attendance/grade, payment, adjustment/refund, đổi branch và failed authorization quan trọng. Audit cần redaction secret/PII và có user, branch, resource, record ID, action, thời điểm, IP, lý do; không dùng cơ chế fire-and-forget có nguy cơ mất log.

Phiếu thu PDF nội bộ gồm số phiếu, ngày/giờ thu, học viên, invoice, số tiền, phương thức, người lập và chi nhánh.

## 10. Các quyết định chi tiết còn mở

| ID | Quyết định cần chốt | Tác động |
|---|---|---|
| BD-01 | BGĐ dùng `ADMIN` hay `DIRECTOR` riêng; nếu riêng, role này read-only hay được sửa? | RBAC, guard, cross-branch data access. |
| BD-02 | Danh sách trạng thái Course/Class và sự kiện chính xác xác định Course “đã bắt đầu”. | Lifecycle, Syllabus lock, API validation. |
| BD-03 | Thời hạn Teacher được nhập/sửa attendance sau session. | UI, API, audit và vận hành lớp. |
| BD-04 | Exam types bắt buộc trong MVP (giữa kỳ/cuối kỳ hay thêm loại khác). | Exam schema, form và report. |
| BD-05 | Quy tắc làm tròn tiền và đơn vị lưu/trình bày tiền VND. | Invoice, payment, receipt và reconciliation. |
| BD-06 | Quy tắc sinh số invoice/receipt; có liên tục theo branch/năm hay không. | Unique constraint, transaction và vận hành kế toán. |
| BD-07 | Refund/adjustment có cần người duyệt thứ hai khác người tạo không; phương thức hoàn tiền nào được hỗ trợ. | Quyền, workflow và audit tài chính. |
| BD-08 | Ai được xác nhận bỏ qua duplicate warning; có bắt buộc lý do không. | UI/API, quyền và chất lượng dữ liệu. |
| BD-09 | Ai được chuyển Lead/Student giữa branch; có cần duyệt từ hai branch không. | Branch policy, migration và audit. |
| BD-10 | Kỳ chốt giờ dạy (tháng hay kỳ tùy chọn), ai khóa/mở lại và điều kiện mở lại. | Báo cáo giờ dạy/payroll. |

## 11. Nguyên tắc triển khai

- Không triển khai quy tắc tài chính hoặc thay đổi schema phụ thuộc vào BD-01–BD-10 cho đến khi có quyết định cụ thể.
- Ưu tiên Phase 0 security/scope và Phase 1 branch isolation/API contract trước module nghiệp vụ mới.
- Mỗi vertical slice phải gồm migration, DTO/validation, backend authorization/branch scope, UI thật, audit/transaction phù hợp và tests.
- Các baseline ở tài liệu này cần được cập nhật nếu Product Owner/chủ nghiệp vụ thay đổi quyết định.

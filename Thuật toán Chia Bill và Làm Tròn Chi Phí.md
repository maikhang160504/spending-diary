# Thuật toán Chia Bill và Làm Tròn Chi Phí

## Mục tiêu

Hệ thống thực hiện chia đều tổng chi phí cho các thành viên trong nhóm, đồng thời làm tròn kết quả đến hàng nghìn đồng để thuận tiện cho việc thanh toán thực tế.

Trong trường hợp phát sinh chênh lệch do làm tròn, phần chênh lệch sẽ được điều chỉnh vào người đã thanh toán (payer), giúp các thành viên còn lại có mức đóng góp đồng đều và dễ thanh toán hơn.

---

## Thuật toán phân bổ chi phí

### Đầu vào

- `total`: Tổng chi phí của nhóm.
- `memberCount`: Tổng số thành viên tham gia chia bill.
- `payerIndex`: Vị trí của thành viên đã thanh toán.

### Bước 1: Tính mức chia trung bình

```text
exactShare = total / memberCount
```

### Bước 2: Làm tròn đến hàng nghìn

Mức chi phí của các thành viên không phải người thanh toán được làm tròn lên đến bội số 1.000 VNĐ gần nhất.

```text
share = ceil(exactShare / 1000) × 1000
```

### Bước 3: Gán chi phí cho các thành viên không phải người thanh toán

```text
cost[i] = share
```

với mọi thành viên khác người thanh toán.

### Bước 4: Tính chi phí của người thanh toán

Người thanh toán nhận phần chi phí còn lại để đảm bảo tổng phân bổ bằng tổng chi phí thực tế.

```text
cost[payer] = total - Σ(cost của các thành viên còn lại)
```

---

## Ví dụ

### Dữ liệu đầu vào

```text
Tổng tiền: 1.000.000 VNĐ
Số thành viên: 3
Người thanh toán: A
```

### Tính toán

```text
exactShare = 1.000.000 / 3
           = 333.333 VNĐ
```

```text
share = 334.000 VNĐ
```

Gán cho B và C:

```text
B = 334.000 VNĐ
C = 334.000 VNĐ
```

Tính phần còn lại cho A:

```text
A = 1.000.000 - 334.000 - 334.000
  = 332.000 VNĐ
```

### Kết quả

| Thành viên | Chi phí |
|------------|---------:|
| A (Payer) | 332.000 |
| B | 334.000 |
| C | 334.000 |

Tổng:

```text
332.000 + 334.000 + 334.000 = 1.000.000 VNĐ
```

---

## Mã giả (Pseudo Code)

```pseudo
function splitBill(total, memberCount, payerIndex):

    exactShare = total / memberCount

    share = ceil(exactShare / 1000) * 1000

    cost = array(memberCount)

    for i from 0 to memberCount - 1:
        if i != payerIndex:
            cost[i] = share

    cost[payerIndex] =
        total - sum(cost của các thành viên còn lại)

    return cost
```

---

## Tính công nợ sau khi chia bill

Sau khi xác định chi phí cuối cùng của từng thành viên, hệ thống tính chênh lệch giữa số tiền đã thanh toán và số tiền thực tế phải chịu.

```text
balance = paidAmount - actualCost
```

Trong đó:

- `balance > 0`: Thành viên được nhận lại tiền.
- `balance < 0`: Thành viên cần thanh toán thêm.
- `balance = 0`: Thành viên đã thanh toán đủ.

### Ví dụ

#### Số tiền đã thanh toán

| Thành viên | Đã thanh toán |
|------------|--------------:|
| A | 600.000 |
| B | 300.000 |
| C | 100.000 |

#### Chi phí sau chia bill

| Thành viên | Chi phí |
|------------|---------:|
| A | 332.000 |
| B | 334.000 |
| C | 334.000 |

#### Công nợ

```text
A = 600.000 - 332.000 = +268.000
B = 300.000 - 334.000 = -34.000
C = 100.000 - 334.000 = -234.000
```

Kết quả thanh toán:

```text
B → A : 34.000 VNĐ
C → A : 234.000 VNĐ
```

Sau khi hoàn tất các khoản thanh toán trên, công nợ của toàn bộ thành viên sẽ bằng 0.
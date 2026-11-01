"""Synthetic only; never use these addresses for real sending."""
import csv
from pathlib import Path
from openpyxl import Workbook


def generate(root):
    root = Path(root)
    root.mkdir(parents=True, exist_ok=True)
    rows = []
    for i in range(1000):
        address = f'user{i}@example.com'
        if i % 20 == 0:
            address = 'sample.person+tag@gmail.com'
        elif i % 20 == 1:
            address = 'sampleperson@gmail.com'
        elif i % 20 == 2:
            address = 'sai@@example.com'
        elif i % 20 == 3:
            address = None
        elif i % 20 == 4:
            address = f'user{i}@missing-example.net'
        elif i % 20 == 5:
            address = f'user{i}@null-example.net'
        elif i % 20 == 6:
            address = f'user{i}@timeout-example.net'
        elif i % 20 == 7:
            address = f'user{i}@implicit-example.net'
        elif i % 20 == 8:
            address = 'a.b@workspace-example.net'
        elif i % 20 == 9:
            address = 'ab@workspace-example.net'
        rows.append([i+1, f'Người thử {i+1}', address, '=HYPERLINK("https://example.com","Dữ liệu thử")' if i == 0 else '+123' if i == 1 else '@ghi chú' if i == 2 else 'Dữ liệu giả; không gửi thư'])
    headers = ['STT','Họ tên','Email','Ghi chú']
    wb = Workbook()
    ws = wb.active
    ws.title = 'Danh sách'
    ws.append(headers)
    for row in rows:
        ws.append(row)
    # Store formula-shaped source as literal for fixture accuracy.
    ws['D2'].data_type = 's'
    wb.create_sheet('Sheet khác')['A1'] = 'Không thuộc sheet được chọn'
    wb.save(root / 'Du-lieu-gia-1000.xlsx')
    with (root / 'Du-lieu-gia-1000.csv').open('w', encoding='utf-8-sig', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(rows)
    return headers, rows


if __name__ == '__main__':
    import sys
    generate(sys.argv[1] if len(sys.argv)>1 else 'sample')

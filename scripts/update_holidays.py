#!/usr/bin/env python3
"""从 holiday-cn 下载指定年份的放假调休安排，严格校验后生成 Sources/NiumaBuddy/BuiltinHolidays.swift

用法：python3 -I scripts/update_holidays.py 2026 2027

数据来自 https://github.com/NateScarlet/holiday-cn（MIT），整理自国务院办公厅每年的放假通知。
生成的代码只包含通过正则校验的日期、节日名（仅汉字和顿号）和布尔值，不会把下载内容原样拼进源码。
"""
import json
import re
import sys
import urllib.request
from pathlib import Path

URL = "https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/{year}.json"
MAX_BYTES = 256 * 1024
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
NAME_RE = re.compile(r"^[一-鿿、]{1,20}$")
PAPER_RE = re.compile(r"^https://www\.gov\.cn/[A-Za-z0-9/_.\-]+$")
OUTPUT = Path(__file__).resolve().parent.parent / "Sources" / "NiumaBuddy" / "BuiltinHolidays.swift"


def fail(message):
    sys.exit(f"错误：{message}")


def fetch(year):
    with urllib.request.urlopen(URL.format(year=year), timeout=20) as resp:
        raw = resp.read(MAX_BYTES + 1)
    if len(raw) > MAX_BYTES:
        fail(f"{year} 年的数据超过 {MAX_BYTES} 字节")
    data = json.loads(raw)
    if data.get("year") != year:
        fail(f"{year} 年的文件里 year 字段不对")
    days = data.get("days")
    if not isinstance(days, list) or not days:
        fail(f"{year} 年还没公布（days 为空）")
    result = []
    for day in days:
        date, name, off = day.get("date"), day.get("name"), day.get("isOffDay")
        if not (isinstance(date, str) and DATE_RE.match(date) and abs(int(date[:4]) - year) <= 1):
            fail(f"非法日期：{date!r}")
        if not (isinstance(name, str) and NAME_RE.match(name)):
            fail(f"非法节日名：{name!r}")
        if not isinstance(off, bool):
            fail(f"isOffDay 不是布尔值：{off!r}")
        result.append((date, name, off))
    papers = [p for p in data.get("papers", []) if isinstance(p, str) and PAPER_RE.match(p)]
    return result, papers


def main():
    try:
        years = sorted({int(arg) for arg in sys.argv[1:]})
    except ValueError:
        fail("年份要是数字")
    if not years or any(y < 2000 or y > 2100 for y in years):
        fail("用法：python3 -I scripts/update_holidays.py 2026 2027")

    lines = [
        "// 由 scripts/update_holidays.py 生成，不要手改",
        "// 数据来自 holiday-cn（https://github.com/NateScarlet/holiday-cn），整理自国务院办公厅放假通知：",
    ]
    body = []
    for year in years:
        days, papers = fetch(year)
        for paper in papers:
            lines.append(f"//   {year}：{paper}")
        body.append(f"        HolidayYear(year: {year}, days: [")
        for date, name, off in days:
            body.append(f'            HolidayDay(date: "{date}", name: "{name}", isOffDay: {"true" if off else "false"}),')
        body.append("        ]),")
        print(f"{year} 年：{len(days)} 天")

    lines += ["", "enum BuiltinHolidays {", "    static let years: [HolidayYear] = ["]
    lines += body
    lines += ["    ]", "}", ""]
    OUTPUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"已写入 {OUTPUT}")


if __name__ == "__main__":
    main()

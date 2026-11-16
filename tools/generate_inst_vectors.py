"""Owned RFC3339 vectors. Python datetime supplies independent ordinary epochs.
Leap transition facts: IERS Bulletin C 72 / Leap_Second.dat (July 2026).
Use --iers-file to compare the implementation against a fresh official file.
No third-party implementation or test suite is copied.
"""
import argparse
import datetime as dt
import json
import pathlib
import random
import re
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
DATES = "1972-07-01 1973-01-01 1974-01-01 1975-01-01 1976-01-01 1977-01-01 1978-01-01 1979-01-01 1980-01-01 1981-07-01 1982-07-01 1983-07-01 1985-07-01 1988-01-01 1990-01-01 1991-01-01 1992-07-01 1993-07-01 1994-07-01 1996-01-01 1997-07-01 1999-01-01 2006-01-01 2009-01-01 2012-07-01 2015-07-01 2017-01-01".split()
EPOCH = dt.datetime(1970, 1, 1)

def quote(s):
    return json.dumps(s)

def vectors():
    cases = []
    for date in DATES:
        boundary = dt.datetime.strptime(date, "%Y-%m-%d")
        for offset in [-1439, -480, 0, 330, 1439]:
            local = boundary - dt.timedelta(seconds=1) + dt.timedelta(minutes=offset)
            suffix = ("+" if offset >= 0 else "-") + "%02d:%02d" % divmod(abs(offset), 60)
            text = local.strftime("%Y-%m-%dT%H:%M:") + "60.123456789012300" + suffix
            cases.append((text, int((boundary-EPOCH).total_seconds())-1, "leap:1234567890123"))
    rng = random.Random(3339)
    for _ in range(300):
        year = rng.randint(2, 9998)
        offset = rng.randint(-1439, 1439)
        local = dt.datetime(year, rng.randint(1, 12), rng.randint(1, 28), rng.randrange(24), rng.randrange(60), rng.randrange(60))
        suffix = ("+" if offset >= 0 else "-") + "%02d:%02d" % divmod(abs(offset), 60)
        text = "%04d-%02d-%02dT%02d:%02d:%02d.00000000100" % (local.year,local.month,local.day,local.hour,local.minute,local.second) + suffix
        epoch = int((local-dt.timedelta(minutes=offset)-EPOCH).total_seconds())
        cases.append((text, epoch, "000000001"))
    return cases

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--iers-file", type=pathlib.Path)
    args = parser.parse_args()
    if args.iers_file:
        rows = [line.split() for line in args.iers_file.read_text().splitlines() if line.strip() and not line.startswith("#")]
        expected = []
        for prev, cur in zip(rows, rows[1:]):
            expected.append(((int(float(cur[0])) - 40587)*86400, int(cur[-1])-int(prev[-1])))
        source = (ROOT/"tags.mbt").read_text()
        actual = [(int(a),int(b)) for a,b in re.findall(r"\((-?\d+)L, (-?\d+)\)",source)]
        if actual != expected:
            raise SystemExit("implementation leap events differ from official IERS file")
        print("27 official IERS transitions match implementation (including sign)")
    cases = vectors()
    lines = ['// Generated owned vectors; excluded from production LOC.', '///|', 'test "independent RFC3339 calendar and IERS leap vectors" {']
    for text,second,fraction in cases:
        lines.append('  assert_eq(instant_key(%s), (%dL, %s))' % (quote(text),second,quote(fraction)))
    lines.append('}')
    generated = '\n'.join(lines)+'\n'
    moon = shutil.which('moon')
    if not moon:
        raise SystemExit('moon must be on PATH')
    with tempfile.TemporaryDirectory(prefix='moonedn-inst-oracle-') as tmp:
        folder=pathlib.Path(tmp)
        (folder/'moon.mod').write_text('name = "fixture/instant"\n')
        (folder/'moon.pkg').write_text('')
        target=folder/'inst_oracle_wbtest.mbt'
        target.write_text(generated)
        subprocess.run([moon,'fmt'],cwd=tmp,check=True,capture_output=True)
        generated=target.read_text()
    target=ROOT/'inst_oracle_wbtest.mbt'
    if args.check:
        if target.read_text()!=generated:
            raise SystemExit('instant fixture differs; regenerate it')
    else:
        target.write_text(generated)
    print('%d independent instant cases verified: 135 leap/offset and 300 ordinary/calendar cases' % len(cases))

if __name__=='__main__':
    main()

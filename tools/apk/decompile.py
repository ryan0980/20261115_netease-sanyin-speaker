"""Decompile selected classes of an APK with androguard (DAD decompiler).

usage:
    pip install androguard
    python decompile.py <app.apk> <out-dir> [class-name-filter]

Default filter is "confignet" (the NetEase Sanyin provisioning package).
Note: most methods in this APK are nativized by NetEase NIS (YiDun) protection,
so decompiled sources are partial - but string constants are still visible.
"""
import os
import sys
import zipfile

from loguru import logger

logger.remove()

from androguard.core.analysis.analysis import Analysis
from androguard.core.dex import DEX
from androguard.decompiler.decompiler import DecompilerDAD


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    apk = sys.argv[1]
    outdir = sys.argv[2]
    name_filter = sys.argv[3] if len(sys.argv) > 3 else "confignet"
    os.makedirs(outdir, exist_ok=True)

    z = zipfile.ZipFile(apk)
    dex_names = [n for n in z.namelist() if n.endswith(".dex")]
    lines = []
    ok = fail = 0

    for dex_name in dex_names:
        print(f"parsing {dex_name} ...", flush=True)
        d = DEX(z.read(dex_name))
        dx = Analysis(d)
        dx.create_xref()
        d.set_decompiler(DecompilerDAD(d, dx))

        targets = [cl for cl in d.get_classes() if name_filter in cl.get_name()]
        print(f"  {len(targets)} classes match '{name_filter}'", flush=True)
        for cl in targets:
            lines.append("")
            lines.append("/" * 100)
            lines.append(f"// {cl.get_name()}")
            lines.append("/" * 100)
            try:
                src = cl.get_source()
                lines.append(src if src else "// <empty>")
                ok += 1
            except Exception as e:
                lines.append(f"// DECOMPILE FAILED: {type(e).__name__}: {e}")
                fail += 1

    out = os.path.join(outdir, "decompiled.java.txt")
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"saved {out} (ok={ok} fail={fail})")


if __name__ == "__main__":
    main()

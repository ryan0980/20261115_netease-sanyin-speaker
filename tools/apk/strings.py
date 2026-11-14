import os
import struct
import sys
import zipfile


def uleb128(buf, off):
    result = 0
    shift = 0
    while True:
        b = buf[off]
        off += 1
        result |= (b & 0x7F) << shift
        if not (b & 0x80):
            break
        shift += 7
    return result, off


def decode_mutf8(raw):
    raw = raw.replace(b"\xc0\x80", b"\x00")
    try:
        return raw.decode("utf-8", "surrogatepass")
    except Exception:
        return raw.decode("utf-8", "replace")


def dex_strings(data):
    string_ids_size, string_ids_off = struct.unpack_from("<II", data, 0x38)
    out = []
    for i in range(string_ids_size):
        (soff,) = struct.unpack_from("<I", data, string_ids_off + i * 4)
        _, p = uleb128(data, soff)
        end = data.index(b"\x00", p)
        out.append(decode_mutf8(data[p:end]))
    return out


def main():
    if len(sys.argv) < 3:
        print("usage: strings.py <app.apk> <out-dir>")
        sys.exit(1)
    apk, outdir = sys.argv[1], sys.argv[2]
    os.makedirs(outdir, exist_ok=True)

    z = zipfile.ZipFile(apk)
    all_strings = []
    for name in [n for n in z.namelist() if n.endswith(".dex")]:
        strings = dex_strings(z.read(name))
        all_strings.extend(strings)
        with open(os.path.join(outdir, name + ".txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(strings))
        print(f"{name}: {len(strings)} strings")

    with open(os.path.join(outdir, "all-strings.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(all_strings))
    print(f"total: {len(all_strings)} -> {os.path.join(outdir, 'all-strings.txt')}")


if __name__ == "__main__":
    main()

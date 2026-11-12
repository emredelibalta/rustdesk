"""Update the project's standard RDPKG resource using a verified customer base."""
import argparse
import ctypes
import hashlib
import re
import shutil
import struct
from pathlib import Path, PurePosixPath
import brotli

BASE_SHA256 = 'c149ec67175abaf83c4e7a7fd57ff6fd4118bb2efb0bc046dde396a1abd5ddd5'
MAGIC = b'rustdesk'

def entries(data):
    for match in re.finditer(MAGIC, data):
        at = match.end()
        result = []
        try:
            while len(result) < 1000:
                if data[at:at+8] == MAGIC:
                    assert data[at+8:at+25] == b'.\\TempoDestek.exe'
                    assert len(result) > 10
                    return result
                n = struct.unpack_from('>I', data, at)[0]
                at += 4
                assert 1 <= n <= 1024
                name = data[at:at+n].decode('utf-8').replace('\\', '/')
                at += n
                assert name.startswith('./')
                name = name[2:]
                path = PurePosixPath(name)
                assert not path.is_absolute() and '..' not in path.parts and ':' not in name
                size = struct.unpack_from('>I', data, at)[0]
                at += 4
                assert 0 < size < 150*1024*1024 and at+size+32 <= len(data)
                compressed = data[at:at+size]
                at += size
                digest = data[at:at+32]
                at += 32
                assert re.fullmatch(b'[a-f0-9]{32}', digest)
                result.append((name, compressed, digest))
        except (AssertionError, ValueError, UnicodeError, struct.error):
            continue
    raise ValueError('Verified portable payload not found')

def unpack(exe, destination):
    data = exe.read_bytes()
    if hashlib.sha256(data).hexdigest() != BASE_SHA256:
        raise ValueError('Customer base SHA256 mismatch')
    destination.mkdir(parents=True, exist_ok=True)
    records = entries(data)
    seen = set()
    for name, compressed, digest in records:
        if name.lower() in seen:
            raise ValueError('Duplicate payload path')
        seen.add(name.lower())
        content = brotli.decompress(compressed)
        if hashlib.md5(content).hexdigest().encode() != digest:
            raise ValueError('Payload checksum mismatch: '+name)
        output = destination/name
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(content)
    print('Verified and extracted customer base files:', len(records))

def resource_update(exe, blob):
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.BeginUpdateResourceW.argtypes = [ctypes.c_wchar_p, ctypes.c_int]
    kernel.BeginUpdateResourceW.restype = ctypes.c_void_p
    kernel.UpdateResourceW.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_wchar_p, ctypes.c_ushort, ctypes.c_void_p, ctypes.c_uint]
    kernel.UpdateResourceW.restype = ctypes.c_int
    kernel.EndUpdateResourceW.argtypes = [ctypes.c_void_p, ctypes.c_int]
    kernel.EndUpdateResourceW.restype = ctypes.c_int
    handle = kernel.BeginUpdateResourceW(str(exe.resolve()), False)
    if not handle:
        raise ctypes.WinError(ctypes.get_last_error())
    buffer = ctypes.create_string_buffer(blob)
    if not kernel.UpdateResourceW(handle, ctypes.c_void_p(10), 'RDPKG', 0, buffer, len(blob)):
        error = ctypes.get_last_error()
        kernel.EndUpdateResourceW(handle, True)
        raise ctypes.WinError(error)
    if not kernel.EndUpdateResourceW(handle, False):
        raise ctypes.WinError(ctypes.get_last_error())

def pack(base_exe, baseline, bundle, output):
    if hashlib.sha256(base_exe.read_bytes()).hexdigest() != BASE_SHA256:
        raise ValueError('Customer base SHA256 mismatch')
    if (bundle/'librustdesk.dll').read_bytes() != (baseline/'librustdesk.dll').read_bytes():
        raise ValueError('Native customer DLL changed')
    blob = bytearray(MAGIC)
    names = []
    for source in sorted(bundle.rglob('*')):
        if not source.is_file():
            continue
        name = source.relative_to(bundle).as_posix()
        original = baseline/name
        content = source.read_bytes()
        if name != 'TempoDestek.exe' and original.is_file() and original.read_bytes() == content:
            continue
        path = ('./'+name).encode()
        compressed = brotli.compress(content, quality=11)
        blob.extend(struct.pack('>I', len(path))+path+struct.pack('>I', len(compressed))+compressed+hashlib.md5(content).hexdigest().encode())
        names.append(name)
    if 'data/app.so' not in names or 'TempoDestek.exe' not in names:
        raise ValueError('New Flutter UI or executable missing')
    blob.extend(MAGIC+b'.\\TempoDestek.exe')
    output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(base_exe, output)
    resource_update(output, bytes(blob))
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.LoadLibraryExW.argtypes = [ctypes.c_wchar_p, ctypes.c_void_p, ctypes.c_uint]
    kernel.LoadLibraryExW.restype = ctypes.c_void_p
    kernel.FindResourceW.argtypes = [ctypes.c_void_p, ctypes.c_wchar_p, ctypes.c_void_p]
    kernel.FindResourceW.restype = ctypes.c_void_p
    kernel.SizeofResource.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
    kernel.SizeofResource.restype = ctypes.c_uint
    kernel.LoadResource.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
    kernel.LoadResource.restype = ctypes.c_void_p
    kernel.LockResource.argtypes = [ctypes.c_void_p]
    kernel.LockResource.restype = ctypes.c_void_p
    kernel.FreeLibrary.argtypes = [ctypes.c_void_p]
    module = kernel.LoadLibraryExW(str(output.resolve()), None, 2)
    if not module:
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        info = kernel.FindResourceW(module, 'RDPKG', ctypes.c_void_p(10))
        if not info:
            raise ValueError('RDPKG resource missing')
        size = kernel.SizeofResource(module, info)
        handle = kernel.LoadResource(module, info)
        pointer = kernel.LockResource(handle)
        if not pointer or ctypes.string_at(pointer, size) != bytes(blob):
            raise ValueError('RDPKG resource verification failed')
    finally:
        kernel.FreeLibrary(module)
    print('Customer UI package files:', ', '.join(names))
    print('SHA256:', hashlib.sha256(output.read_bytes()).hexdigest())

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=['unpack', 'pack'])
    parser.add_argument('--base-exe', type=Path, required=True)
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--bundle', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if args.mode == 'unpack':
        unpack(args.base_exe, args.baseline)
    else:
        if args.bundle is None or args.output is None:
            parser.error('--bundle and --output required for pack')
        pack(args.base_exe, args.baseline, args.bundle, args.output)

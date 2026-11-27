#!/usr/bin/env python3
"""Extract structural evidence from JSON .ips reports; does not symbolicate."""
import argparse
import json
import sys
from pathlib import Path


def documents(text):
    decoder = json.JSONDecoder()
    remaining = text.lstrip('\ufeff \t\r\n')
    result = []
    while remaining:
        item, end = decoder.raw_decode(remaining)
        if not isinstance(item, dict):
            raise ValueError('Each IPS JSON document must be an object')
        result.append(item)
        remaining = remaining[end:].lstrip()
    if not result:
        raise ValueError('Empty report')
    return result


def inventory(text):
    docs = documents(text)
    if len(docs) > 2:
        raise ValueError('Expected one report object or metadata followed by report')
    metadata = docs[0] if len(docs) == 2 else {}
    report = docs[-1]
    threads = report.get('threads', [])
    images = report.get('usedImages', [])
    if not isinstance(threads, list) or not isinstance(images, list):
        raise ValueError('threads and usedImages must be arrays')
    if any(not isinstance(item, dict) for item in threads + images):
        raise ValueError('Thread and image entries must be objects')
    index = report.get('faultingThread')
    selected_index = None
    selection = None
    if type(index) is int and 0 <= index < len(threads):
        selected_index, selection = index, 'faultingThread'
    else:
        triggered = [i for i, thread in enumerate(threads) if thread.get('triggered') is True]
        if len(triggered) == 1:
            selected_index, selection = triggered[0], 'triggered'
        elif len(triggered) > 1:
            selection = 'ambiguous_triggered'
    frames = threads[selected_index].get('frames', []) if selected_index is not None else []
    if not isinstance(frames, list) or any(not isinstance(f, dict) for f in frames):
        raise ValueError('Frames must be an array of objects')
    mapped = []
    for frame in frames:
        image_index = frame.get('imageIndex')
        image = images[image_index] if type(image_index) is int and 0 <= image_index < len(images) else {}
        base, offset = image.get('base'), frame.get('imageOffset')
        address = None
        if type(base) is int and type(offset) is int and base >= 0 and offset >= 0:
            address = f'0x{base + offset:x}'
        mapped.append({key: value for key, value in {
            'image': image.get('name'), 'uuid': image.get('uuid'), 'architecture': image.get('arch'),
            'image_base': base, 'image_offset': offset, 'instruction_address_hex': address,
            'symbol': frame.get('symbol'), 'symbol_location': frame.get('symbolLocation')}.items() if value is not None})
    return {'document_count': len(docs), 'bug_type': metadata.get('bug_type', report.get('bug_type')),
            'process': report.get('procName'), 'bundle': report.get('bundleInfo'),
            'os': report.get('osVersion'), 'exception': report.get('exception'),
            'termination': report.get('termination'), 'faulting_thread_index': index,
            'selected_thread_index': selected_index, 'thread_selection': selection,
            'faulting_frames': mapped, 'image_count': len(images),
            'limitations': ['Does not classify root cause, verify dSYM UUIDs, or symbolicate addresses.',
                            'No faulting frames can mean incomplete input or a non-crash report; it does not prove safety.',
                            'Only selected fields are shown; inspect the original report for other threads and exception backtraces.']}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('report', type=Path)
    args = p.parse_args()
    try:
        result = inventory(args.report.read_text())
    except (OSError, ValueError, RecursionError) as exc:
        print(json.dumps({'error': str(exc)}), file=sys.stderr)
        return 2
    print(json.dumps(result, indent=2))
    return 0


if __name__ == '__main__':
    sys.exit(main())

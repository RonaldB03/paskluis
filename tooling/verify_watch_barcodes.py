"""Decode the exact transmitted module grid with an independent scanner.

Requires Pillow and zxing-cpp. Input contains only generated test data.
"""
import json
from pathlib import Path
from PIL import Image, ImageDraw
import zxingcpp

root = Path(__file__).resolve().parent.parent
fixtures = json.loads((root / 'build/watch-fixtures.json').read_text())
for card in fixtures:
    w, h = card['width'], card['height']
    q = 10 if h == 1 else 4
    # Four pixels per module; no smoothing. Device scanability needs hardware QA.
    m = 4
    row_height = 80 if h == 1 else m
    image = Image.new('RGB', ((w+2*q)*m, h*row_height+2*q*m), 'white')
    draw = ImageDraw.Draw(image)
    for y in range(h):
        for x in range(w):
            i = y*w+x
            if int(card['bits'][i//4],16) & (1 << (3-i%4)):
                left, top = (x+q)*m, q*m+y*row_height
                draw.rectangle((left, top, left+m-1, top+row_height-1),fill='black')
    results = zxingcpp.read_barcodes(image)
    assert len(results) == 1, f"Could not independently decode {card['id']}"
    if h > 1:
        assert results[0].format == zxingcpp.BarcodeFormat.QRCode, card['id']
    # ZXing may report UPC-A as EAN-13 with a leading zero, and expands UPC-E.
    actual = results[0].text
    expected = card['code']
    if expected == '01234565':
        assert actual in ('012345000065','0012345000065',expected), (card['id'], actual)
    else:
        assert actual == expected or ('0'+actual == expected) or (actual == '0'+expected), (card['id'],actual,expected)
    print(card['id'], results[0].format, 'PASS')
print(f'{len(fixtures)} barcode round trips passed.')

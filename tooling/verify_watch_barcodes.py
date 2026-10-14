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

# Model the exact Garmin integer-pixel renderer, including the circular bezel.
wide = next(c for c in fixtures if c['width'] == 211 and c['height'] == 1)
for size in (240, 260, 280):
    w = wide['width']
    m = int(size * .97) // (w + 20)
    bh = int(size * .24)
    x0, y0 = (size - w*m)//2, (size - bh)//2
    image = Image.new('RGB', (size, size), 'black')
    draw = ImageDraw.Draw(image)
    draw.ellipse((0, 0, size-1, size-1), fill='white')
    for x in (x0-10*m, x0+(w+10)*m-1):
        for y in (y0, y0+bh-1):
            assert (x-size/2)**2 + (y-size/2)**2 < (size/2)**2
    for x in range(w):
        if int(wide['bits'][x//4],16) & (1 << (3-x%4)):
            draw.rectangle((x0+x*m,y0,x0+(x+1)*m-1,y0+bh-1),fill='black')
    result = zxingcpp.read_barcode(image)
    assert result and result.text == wide['code'] and result.format == zxingcpp.BarcodeFormat.Code128
    print(f'{size}px circular Garmin: complete wide barcode decoded')

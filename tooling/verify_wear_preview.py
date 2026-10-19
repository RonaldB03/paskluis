"""Independently decode synthetic codes from actual Wear emulator captures.

Requires Pillow and zxing-cpp. Never supply screenshots of real customer cards.
"""
from pathlib import Path
import sys
from PIL import Image, ImageDraw
import zxingcpp

folder = Path(sys.argv[1])
expected = {
    'wear-barcode.png': '0123456789012',
    'wear-swiped-code.png': '0123456789012',
    'wear-gift.png': '0123456789012',
    'wear-qr.png': ''.join(chr(97 + i % 26) for i in range(300)),
}
for name, code in expected.items():
    image = Image.open(folder / name).convert('RGB')
    assert image.getpixel((image.width // 2, 0)) == (0, 0, 0), name
    assert image.getpixel((image.width // 2, image.height - 1)) == (0, 0, 0), name
    # Account for the physical round display, not only the rectangular capture.
    mask = Image.new('L', image.size, 0)
    ImageDraw.Draw(mask).ellipse((0, 0, image.width - 1, image.height - 1), fill=255)
    round_screen = Image.new('RGB', image.size, 'black')
    round_screen.paste(image, mask=mask)
    results = zxingcpp.read_barcodes(round_screen)
    assert len(results) == 1 and results[0].text == code, f'Round screen decode failed: {name}'
    if 'qr' in name:
        assert results[0].format == zxingcpp.BarcodeFormat.QRCode
    print(f'{name}: full code decoded on round black screen')

for name in ('wear-passes.png', 'wear-scroll.png', 'wear-settings.png'):
    image = Image.open(folder / name).convert('RGB')
    # The visible white curved position indicator occupies the outer right edge.
    edge = image.crop((int(image.width * .94), image.height // 3, image.width, image.height * 2 // 3))
    assert sum(edge.getpixel((x, y)) == (255, 255, 255)
               for y in range(edge.height) for x in range(edge.width)) > 10, f'Missing visible indicator: {name}'
    print(f'{name}: scrollbar visible')

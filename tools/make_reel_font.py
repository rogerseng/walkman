"""Builds TapeReels.ttf, the font that makes the reels turn on the lock screen.

Lock screen widgets cannot run animations, but a timer text redraws itself every
second. In this font each digit is a picture of a cassette hub, and each digit is
turned 18 degrees further than the one before. A timer shown in this font, cut
down to its last digit, is therefore a hub that steps round once a second. The
hub has six teeth, so after ten steps (180 degrees) it lines up with the start.

Run:  python3 tools/make_reel_font.py
"""
import math
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

EM = 1000
CENTER = 500
OUTER, INNER, TOOTH_TIP, TOOTH_HALF_WIDTH = 490, 285, 150, 55
STEP_DEGREES = 18


def point(radius, angle):
    return (round(CENTER + radius * math.cos(angle)), round(CENTER + radius * math.sin(angle)))


def hub(rotation):
    pen = TTGlyphPen(None)
    # Outer edge, clockwise.
    ring = [point(OUTER, -2 * math.pi * i / 96) for i in range(96)]
    pen.moveTo(ring[0])
    for p in ring[1:]:
        pen.lineTo(p)
    pen.closePath()
    # Hole in the middle, counter clockwise, with six teeth reaching inward.
    at_rim = math.asin(TOOTH_HALF_WIDTH / INNER)
    at_tip = math.asin(TOOTH_HALF_WIDTH / TOOTH_TIP)
    hole = []
    for k in range(6):
        here = rotation + k * math.pi / 3
        there = here + math.pi / 3
        for i in range(9):
            hole.append(point(INNER, here + at_rim + (there - here - 2 * at_rim) * i / 8))
        hole.append(point(TOOTH_TIP, there - at_tip))
        hole.append(point(TOOTH_TIP, there + at_tip))
    pen.moveTo(hole[0])
    for p in hole[1:]:
        pen.lineTo(p)
    pen.closePath()
    return pen.glyph()


def empty():
    return TTGlyphPen(None).glyph()


digits = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
order = [".notdef", "space", "colon"] + digits
glyphs = {".notdef": empty(), "space": empty(), "colon": empty()}
for n, name in enumerate(digits):
    glyphs[name] = hub(math.radians(STEP_DEGREES * n))

fb = FontBuilder(EM, isTTF=True)
fb.setupGlyphOrder(order)
fb.setupCharacterMap({0x20: "space", 0x3A: "colon", **{0x30 + n: name for n, name in enumerate(digits)}})
fb.setupGlyf(glyphs)
fb.setupHorizontalMetrics({name: (EM if name in digits else 300, 0) for name in order})
fb.setupHorizontalHeader(ascent=EM, descent=0)
fb.setupNameTable({"familyName": "TapeReels", "styleName": "Regular", "psName": "TapeReels"})
fb.setupOS2(sTypoAscender=EM, sTypoDescender=0, sTypoLineGap=0, usWinAscent=EM, usWinDescent=0)
fb.setupPost()
fb.save("TapeDeckWidgets/TapeReels.ttf")

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
OUTPUTS = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def lerp(a, b, t):
    return round(a + (b - a) * t)


def blend(left, right, t):
    return tuple(lerp(left[i], right[i], t) for i in range(4))


def vertical_gradient(size, top, middle, bottom):
    image = Image.new("RGBA", (size, size))
    pixels = image.load()
    for y in range(size):
        t = y / max(size - 1, 1)
        if t < 0.52:
            color = blend(top, middle, t / 0.52)
        else:
            color = blend(middle, bottom, (t - 0.52) / 0.48)
        for x in range(size):
            pixels[x, y] = color
    return image


def rounded_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def draw_icon(size):
    scale = 4
    canvas_size = size * scale
    radius = round(canvas_size * 0.24)
    icon = vertical_gradient(
        canvas_size,
        (98, 228, 182, 255),
        (31, 201, 220, 255),
        (106, 77, 244, 255),
    )
    draw = ImageDraw.Draw(icon, "RGBA")

    draw.ellipse(
        (
            canvas_size * 0.08,
            canvas_size * 0.08,
            canvas_size * 0.58,
            canvas_size * 0.58,
        ),
        fill=(200, 246, 221, 150),
    )
    draw.ellipse(
        (
            canvas_size * 0.42,
            canvas_size * 0.42,
            canvas_size * 1.02,
            canvas_size * 1.02,
        ),
        fill=(255, 215, 229, 150),
    )

    face = (
        canvas_size * 0.18,
        canvas_size * 0.20,
        canvas_size * 0.82,
        canvas_size * 0.84,
    )
    draw.rounded_rectangle(
        face,
        radius=canvas_size * 0.22,
        fill=(255, 255, 255, 244),
        outline=(255, 255, 255, 230),
        width=max(2, round(canvas_size * 0.025)),
    )

    eye_w = canvas_size * 0.08
    eye_h = canvas_size * 0.11
    for cx in (canvas_size * 0.39, canvas_size * 0.61):
        draw.ellipse(
            (cx - eye_w / 2, canvas_size * 0.43, cx + eye_w / 2, canvas_size * 0.43 + eye_h),
            fill=(23, 48, 84, 255),
        )

    cheek = canvas_size * 0.09
    for cx in (canvas_size * 0.34, canvas_size * 0.66):
        draw.ellipse(
            (
                cx - cheek / 2,
                canvas_size * 0.58,
                cx + cheek / 2,
                canvas_size * 0.58 + cheek * 0.72,
            ),
            fill=(255, 183, 209, 210),
        )

    draw.arc(
        (
            canvas_size * 0.42,
            canvas_size * 0.54,
            canvas_size * 0.58,
            canvas_size * 0.72,
        ),
        start=20,
        end=160,
        fill=(23, 48, 84, 255),
        width=max(3, round(canvas_size * 0.03)),
    )

    badge = (
        canvas_size * 0.66,
        canvas_size * 0.12,
        canvas_size * 0.88,
        canvas_size * 0.34,
    )
    draw.ellipse(badge, fill=(255, 229, 157, 255))
    plus_color = (154, 106, 0, 255)
    stroke = max(2, round(canvas_size * 0.025))
    draw.line(
        (canvas_size * 0.77, canvas_size * 0.17, canvas_size * 0.77, canvas_size * 0.29),
        fill=plus_color,
        width=stroke,
    )
    draw.line(
        (canvas_size * 0.71, canvas_size * 0.23, canvas_size * 0.83, canvas_size * 0.23),
        fill=plus_color,
        width=stroke,
    )

    icon.putalpha(rounded_mask(canvas_size, radius))
    return icon.resize((size, size), Image.Resampling.LANCZOS)


def main():
    for folder, size in OUTPUTS.items():
        path = ROOT / "android" / "app" / "src" / "main" / "res" / folder / "ic_launcher.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        draw_icon(size).save(path)
        print(f"wrote {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

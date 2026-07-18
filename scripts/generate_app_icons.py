from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "branding" / "kimjod_sloth_icon.png"
OUTPUTS = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
ADAPTIVE_OUTPUTS = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}


def rounded_mask(size: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(
        (0, 0, size - 1, size - 1),
        radius=round(size * 0.22),
        fill=255,
    )
    return mask


def round_mask(size: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    return mask


def render_icon(source: Image.Image, size: int) -> Image.Image:
    render_size = size * 4
    icon = ImageOps.fit(
        source,
        (render_size, render_size),
        method=Image.Resampling.LANCZOS,
        centering=(0.5, 0.5),
    )
    icon.putalpha(rounded_mask(render_size))
    return icon.resize((size, size), Image.Resampling.LANCZOS)


def render_round_icon(source: Image.Image, size: int) -> Image.Image:
    render_size = size * 4
    icon = ImageOps.fit(
        source,
        (render_size, render_size),
        method=Image.Resampling.LANCZOS,
        centering=(0.5, 0.5),
    )
    icon.putalpha(round_mask(render_size))
    return icon.resize((size, size), Image.Resampling.LANCZOS)


def render_adaptive_foreground(source: Image.Image, size: int) -> Image.Image:
    return ImageOps.fit(
        source,
        (size, size),
        method=Image.Resampling.LANCZOS,
        centering=(0.5, 0.5),
    )


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    for folder, size in OUTPUTS.items():
        path = (
            ROOT
            / "android"
            / "app"
            / "src"
            / "main"
            / "res"
            / folder
            / "ic_launcher.png"
        )
        path.parent.mkdir(parents=True, exist_ok=True)
        render_icon(source, size).save(path, optimize=True)
        print(f"wrote {path.relative_to(ROOT)}")

        round_path = path.with_name("ic_launcher_round.png")
        render_round_icon(source, size).save(round_path, optimize=True)
        print(f"wrote {round_path.relative_to(ROOT)}")

    for folder, size in ADAPTIVE_OUTPUTS.items():
        path = (
            ROOT
            / "android"
            / "app"
            / "src"
            / "main"
            / "res"
            / folder
            / "ic_launcher_foreground.png"
        )
        render_adaptive_foreground(source, size).save(path, optimize=True)
        print(f"wrote {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

from __future__ import annotations

from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "tmp_slip_audit"
SCB = Path(r"C:\Users\ChisanuchaK\OneDrive\Desktop\SCB EASY")
KPLUS = Path(r"C:\Users\ChisanuchaK\OneDrive\Desktop\K PLUS")
PAOTANG = Path(r"C:\Users\ChisanuchaK\OneDrive\Desktop\PaoTang")
DIME = Path(r"C:\Users\ChisanuchaK\OneDrive\Desktop\Dime!")


def image_files(folder: Path) -> list[Path]:
    return sorted(
        p
        for p in folder.iterdir()
        if p.suffix.lower() in {".jpg", ".jpeg", ".png"}
    )


def crop_scb_amount(im: Image.Image) -> Image.Image:
    w, h = im.size
    return im.crop((int(w * 0.02), int(h * 0.55), int(w * 0.98), int(h * 0.71)))


def crop_kplus_amount(im: Image.Image) -> Image.Image:
    w, h = im.size
    return im.crop((int(w * 0.03), int(h * 0.70), int(w * 0.67), int(h * 0.96)))


def crop_paotang_amount(im: Image.Image) -> Image.Image:
    w, h = im.size
    return im.crop((int(w * 0.03), int(h * 0.48), int(w * 0.97), int(h * 0.78)))


def crop_dime_amount(im: Image.Image) -> Image.Image:
    w, h = im.size
    return im.crop((int(w * 0.02), int(h * 0.02), int(w * 0.98), int(h * 0.58)))


def make_sheets(
    name: str,
    files: Iterable[Path],
    cropper,
    *,
    cell_w: int = 460,
    crop_h: int = 128,
    label_h: int = 34,
    cols: int = 3,
    rows: int = 6,
) -> list[Path]:
    OUT.mkdir(parents=True, exist_ok=True)
    font = ImageFont.load_default()
    paths = []
    files = list(files)
    per_page = cols * rows

    for page, start in enumerate(range(0, len(files), per_page), start=1):
        page_files = files[start : start + per_page]
        sheet = Image.new(
            "RGB",
            (cols * cell_w, rows * (crop_h + label_h)),
            "white",
        )
        draw = ImageDraw.Draw(sheet)

        for idx, path in enumerate(page_files):
            col = idx % cols
            row = idx // cols
            x = col * cell_w
            y = row * (crop_h + label_h)

            with Image.open(path) as im:
                crop = cropper(im.convert("RGB"))
            crop.thumbnail((cell_w - 8, crop_h), Image.Resampling.LANCZOS)
            sheet.paste(crop, (x + 4, y + label_h))

            draw.rectangle(
                (x, y, x + cell_w - 1, y + crop_h + label_h - 1),
                outline=(210, 210, 210),
            )
            draw.text((x + 6, y + 8), path.name[:66], fill=(0, 0, 0), font=font)

        out_path = OUT / f"{name}_amount_crops_{page:02d}.jpg"
        sheet.save(out_path, quality=92)
        paths.append(out_path)

    return paths


def main() -> None:
    scb_pages = make_sheets("scb", image_files(SCB), crop_scb_amount)
    kplus_pages = make_sheets(
        "kplus",
        image_files(KPLUS),
        crop_kplus_amount,
        cell_w=520,
        crop_h=190,
        cols=2,
        rows=4,
    )
    paotang_pages = make_sheets(
        "paotang",
        image_files(PAOTANG),
        crop_paotang_amount,
        cell_w=520,
        crop_h=400,
        cols=2,
        rows=3,
    )
    dime_pages = make_sheets(
        "dime",
        image_files(DIME),
        crop_dime_amount,
        cell_w=520,
        crop_h=520,
        cols=2,
        rows=3,
    )
    print(f"SCB pages: {len(scb_pages)}")
    for path in scb_pages:
        print(path)
    print(f"K PLUS pages: {len(kplus_pages)}")
    for path in kplus_pages:
        print(path)
    print(f"PaoTang pages: {len(paotang_pages)}")
    for path in paotang_pages:
        print(path)
    print(f"Dime pages: {len(dime_pages)}")
    for path in dime_pages:
        print(path)


if __name__ == "__main__":
    main()

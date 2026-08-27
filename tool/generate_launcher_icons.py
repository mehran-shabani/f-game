"""Generate Android adaptive, monochrome, round, and legacy launcher icons."""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "branding" / "orbit-breaker-logo.png"
RES = ROOT / "android" / "app" / "src" / "main" / "res"
BRAND_BLUE = (11, 41, 111, 255)
DENSITIES = {
    "mdpi": 1.0,
    "hdpi": 1.5,
    "xhdpi": 2.0,
    "xxhdpi": 3.0,
    "xxxhdpi": 4.0,
}


def extract_white_mark(source: Image.Image) -> Image.Image:
    """Recover a clean white/alpha mark from the solid brand background."""
    rgb = source.convert("RGB")
    background = rgb.getpixel((0, 0))
    channels = rgb.split()
    alpha_channels = []
    for channel, background_value in zip(channels, background):
        denominator = max(1, 255 - background_value)
        lookup = [
            round(max(0, min(1, (value - background_value) / denominator)) * 255)
            for value in range(256)
        ]
        alpha_channels.append(channel.point(lookup))

    alpha = ImageChops.lighter(
        ImageChops.lighter(alpha_channels[0], alpha_channels[1]),
        alpha_channels[2],
    )
    bounds = alpha.point(lambda value: 255 if value > 2 else 0).getbbox()
    if bounds is None:
        raise ValueError("No logo mark could be extracted from the source image.")

    mark = Image.new("RGBA", rgb.size, (255, 255, 255, 0))
    mark.putalpha(alpha)
    return mark.crop(bounds)


def fitted_mark(mark: Image.Image, canvas_size: int, fraction: float) -> Image.Image:
    target = round(canvas_size * fraction)
    scale = min(target / mark.width, target / mark.height)
    resized = mark.resize(
        (round(mark.width * scale), round(mark.height * scale)),
        Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    position = (
        (canvas_size - resized.width) // 2,
        (canvas_size - resized.height) // 2,
    )
    canvas.alpha_composite(resized, position)
    return canvas


def legacy_icon(mark: Image.Image, size: int, shape: str) -> Image.Image:
    supersampling = 4
    large_size = size * supersampling
    canvas = Image.new("RGBA", (large_size, large_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    bounds = (0, 0, large_size - 1, large_size - 1)
    if shape == "circle":
        draw.ellipse(bounds, fill=BRAND_BLUE)
    elif shape == "rounded":
        draw.rounded_rectangle(
            bounds,
            radius=round(large_size * 0.22),
            fill=BRAND_BLUE,
        )
    elif shape == "square":
        draw.rectangle(bounds, fill=BRAND_BLUE)
    else:
        raise ValueError(f"Unknown icon shape: {shape}")

    canvas.alpha_composite(fitted_mark(mark, large_size, 0.61))
    return canvas.resize((size, size), Image.Resampling.LANCZOS)


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)


def save_adaptive_preview(foreground: Image.Image) -> None:
    """Render common OEM masks using Android's 72dp masked viewport."""
    size = foreground.width
    composed = Image.new("RGBA", (size, size), BRAND_BLUE)
    composed.alpha_composite(foreground)
    viewport = round(size * 72 / 108)
    inset = (size - viewport) // 2
    visible = composed.crop((inset, inset, inset + viewport, inset + viewport))
    visible = visible.resize((256, 256), Image.Resampling.LANCZOS)

    sheet = Image.new("RGBA", (896, 320), (239, 242, 248, 255))
    for index, shape in enumerate(("circle", "squircle", "rounded")):
        mask = Image.new("L", (256, 256), 0)
        draw = ImageDraw.Draw(mask)
        if shape == "circle":
            draw.ellipse((0, 0, 255, 255), fill=255)
        elif shape == "squircle":
            draw.rounded_rectangle((0, 0, 255, 255), radius=82, fill=255)
        else:
            draw.rounded_rectangle((0, 0, 255, 255), radius=48, fill=255)
        tile = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        tile.paste(visible, (0, 0), mask)
        sheet.alpha_composite(tile, (32 + index * 288, 32))

    save_png(
        sheet,
        ROOT / "assets" / "branding" / "android-launcher-preview.png",
    )


def main() -> None:
    mark = extract_white_mark(Image.open(SOURCE))
    preview_foreground = None
    for density, multiplier in DENSITIES.items():
        directory = RES / f"mipmap-{density}"
        adaptive_size = round(108 * multiplier)
        legacy_size = round(48 * multiplier)

        # The mark is 64dp wide inside Android's never-clipped 66dp safe zone.
        foreground = fitted_mark(mark, adaptive_size, 64 / 108)
        save_png(foreground, directory / "ic_launcher_foreground.png")
        if density == "xxxhdpi":
            preview_foreground = foreground
        save_png(
            legacy_icon(mark, legacy_size, "rounded"),
            directory / "ic_launcher.png",
        )
        save_png(
            legacy_icon(mark, legacy_size, "circle"),
            directory / "ic_launcher_round.png",
        )

    save_png(
        legacy_icon(mark, 512, "square"),
        ROOT / "assets" / "branding" / "orbit-breaker-playstore-512.png",
    )
    if preview_foreground is not None:
        save_adaptive_preview(preview_foreground)
    print("Android launcher icons generated from", SOURCE)


if __name__ == "__main__":
    main()

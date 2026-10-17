#!/usr/bin/env python3
"""Generate the AppDrop AppIcon asset set from a single source artwork.

Usage:
    python3 Scripts/make-appicon.py <source-image> <AppIcon.appiconset-dir> [preview-png]

What it does:
  1. Detects the artwork's bounding box inside a (white/soft-shadow) source image.
  2. Crops to that box and fills the areas outside the artwork's own rounded
     shape by extending the nearest edge pixels, so the final icon is
     full-bleed: no white margin anywhere (required by the product spec).
  3. Writes the macOS AppIcon set: 16/32/128/256/512 @1x and @2x
     (i.e. 16…1024 px) plus Contents.json.

Requires: Pillow, numpy, scipy.
"""

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image


def detect_bounds(rgb: np.ndarray, threshold: int = 60) -> tuple[int, int, int, int]:
    """Bounding box of the artwork itself.

    The source artwork usually sits on a white background with a soft drop
    shadow. A plain "not near white" mask would include that shadow, so the
    artwork's dominant hue (blue for AppDrop) is used first; plain luma is only
    a fallback for monochrome sources.
    """
    channels = rgb.astype(int)
    red, _green, blue = channels[:, :, 0], channels[:, :, 1], channels[:, :, 2]
    blue_dominant = blue > red + 25
    distance_from_white = (255 - channels).max(axis=2)
    mask = blue_dominant if blue_dominant.mean() > 0.05 else distance_from_white > threshold
    ys, xs = np.where(mask)
    if xs.size == 0:
        raise SystemExit("No artwork detected: the source image looks blank.")
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def fill_outside_shape(
    rgb: np.ndarray,
    dominant_gap: int = 25,
    iterations: int = 250,
    plane_weight: float = 0.7,
) -> np.ndarray:
    """Fill everything outside the artwork's own rounded shape.

    The shape mask is derived from the artwork's dominant hue (so the soft drop
    shadow and the background texture are excluded), closed to cover its
    interior. The outside is then filled with a blend of

      * a least-squares colour plane fitted to the artwork's interior background
        (follows the background gradient into the corners), and
      * a diffusion relaxation seeded from the nearest shape pixel (keeps the
        transition to the artwork's edge smooth).

    Result: full-bleed artwork, no white margin and no visible seam.
    """
    from scipy import ndimage

    channels = rgb.astype(np.float64)
    red, _green, blue = channels[:, :, 0], channels[:, :, 1], channels[:, :, 2]
    shape = blue > red + dominant_gap
    if shape.mean() < 0.2:  # fallback for monochrome artwork
        shape = (255 - channels).max(axis=2) > 60
    shape = ndimage.binary_fill_holes(shape)
    shape = ndimage.binary_closing(shape, structure=np.ones((5, 5)))
    outside = ~shape
    if not outside.any():
        return rgb

    # Diffusion part: nearest shape pixel colour, then relaxation.
    _distance, (indices_y, indices_x) = ndimage.distance_transform_edt(outside, return_indices=True)
    diffused = channels.copy()
    diffused[outside] = channels[indices_y[outside], indices_x[outside]]
    for _ in range(iterations):
        padded = np.pad(diffused, ((1, 1), (1, 1), (0, 0)), mode="edge")
        average = (
            padded[0:-2, 1:-1] + padded[2:, 1:-1] + padded[1:-1, 0:-2] + padded[1:-1, 2:]
        ) / 4.0
        diffused[outside] = average[outside]

    # Plane part: least-squares fit of the interior background colour.
    interior = ndimage.binary_erosion(shape, iterations=26)
    red, _green, blue = channels[:, :, 0], channels[:, :, 1], channels[:, :, 2]
    background = interior & (blue > red + dominant_gap)
    sample_y, sample_x = np.where(background)
    height, width = shape.shape
    grid_y, grid_x = np.mgrid[0:height, 0:width]
    if sample_x.size > 100:
        design = np.stack([np.ones_like(sample_x, dtype=float), sample_x, sample_y], axis=1)
        coefficients, *_ = np.linalg.lstsq(design, channels[sample_y, sample_x], rcond=None)
        plane = np.stack(
            [
                coefficients[0, channel]
                + coefficients[1, channel] * grid_x
                + coefficients[2, channel] * grid_y
                for channel in range(3)
            ],
            axis=2,
        )
    else:
        plane = diffused

    blended = plane_weight * plane + (1.0 - plane_weight) * diffused
    result = rgb.copy()
    result[outside] = np.clip(blended[outside], 0, 255).astype(np.uint8)
    return result


SIZES = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}

CONTENTS_JSON = {
    "images": [
        {"filename": "icon_16x16.png", "idiom": "mac", "scale": "1x", "size": "16x16"},
        {"filename": "icon_16x16@2x.png", "idiom": "mac", "scale": "2x", "size": "16x16"},
        {"filename": "icon_32x32.png", "idiom": "mac", "scale": "1x", "size": "32x32"},
        {"filename": "icon_32x32@2x.png", "idiom": "mac", "scale": "2x", "size": "32x32"},
        {"filename": "icon_128x128.png", "idiom": "mac", "scale": "1x", "size": "128x128"},
        {"filename": "icon_128x128@2x.png", "idiom": "mac", "scale": "2x", "size": "128x128"},
        {"filename": "icon_256x256.png", "idiom": "mac", "scale": "1x", "size": "256x256"},
        {"filename": "icon_256x256@2x.png", "idiom": "mac", "scale": "2x", "size": "256x256"},
        {"filename": "icon_512x512.png", "idiom": "mac", "scale": "1x", "size": "512x512"},
        {"filename": "icon_512x512@2x.png", "idiom": "mac", "scale": "2x", "size": "512x512"},
    ],
    "info": {"author": "xcode", "version": 1},
}


def main() -> None:
    if len(sys.argv) not in (3, 4):
        raise SystemExit(__doc__)
    source_path = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])

    source = Image.open(source_path).convert("RGB")
    rgb = np.array(source)
    left, top, right, bottom = detect_bounds(rgb)
    print(f"source: {source.size}, artwork bounds: ({left}, {top}, {right}, {bottom})")

    cropped = rgb[top:bottom, left:right]
    square = fill_outside_shape(cropped)
    master = Image.fromarray(square).resize((1024, 1024), Image.LANCZOS)

    output_dir.mkdir(parents=True, exist_ok=True)
    for filename, size in SIZES.items():
        resized = master if size == 1024 else master.resize((size, size), Image.LANCZOS)
        resized.save(output_dir / filename, format="PNG")
    (output_dir / "Contents.json").write_text(
        json.dumps(CONTENTS_JSON, indent=2) + "\n", encoding="utf-8"
    )

    if len(sys.argv) == 4:
        preview_path = Path(sys.argv[3])
        preview_path.parent.mkdir(parents=True, exist_ok=True)
        master.save(preview_path, format="PNG")
        print(f"preview: {preview_path}")
    print(f"wrote {len(SIZES)} icon files + Contents.json to {output_dir}")


if __name__ == "__main__":
    main()


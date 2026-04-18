from __future__ import annotations

from dataclasses import dataclass
from typing import Any
import cv2
import numpy as np


# -----------------------------
# Data structure
# -----------------------------
@dataclass
class FeatureResult:
    score: float
    label: str
    keywords: list[str]
    details: dict[str, Any]


# -----------------------------
# Utilities
# -----------------------------
def _normalise_score(value: float, min_value: float, max_value: float) -> float:
    if max_value <= min_value:
        return 0.0
    clipped = max(min_value, min(value, max_value))
    return (clipped - min_value) / (max_value - min_value)


def _largest_contour(mask: np.ndarray) -> np.ndarray | None:
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        return None
    return max(contours, key=cv2.contourArea)


def _resize_for_analysis(image_bgr: np.ndarray, target_width: int = 512) -> np.ndarray:
    h, w = image_bgr.shape[:2]
    if w <= target_width:
        return image_bgr
    scale = target_width / w
    new_size = (int(w * scale), int(h * scale))
    return cv2.resize(image_bgr, new_size, interpolation=cv2.INTER_AREA)


# -----------------------------
# Lesion segmentation
# -----------------------------
def segment_lesion(image_bgr: np.ndarray) -> tuple[np.ndarray, np.ndarray | None]:
    image_bgr = _resize_for_analysis(image_bgr)

    blurred = cv2.GaussianBlur(image_bgr, (5, 5), 0)
    lab = cv2.cvtColor(blurred, cv2.COLOR_BGR2LAB)
    l_channel, _, _ = cv2.split(lab)

    _, dark_mask = cv2.threshold(
        l_channel, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU
    )

    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    cleaned = cv2.morphologyEx(dark_mask, cv2.MORPH_OPEN, kernel, iterations=1)
    cleaned = cv2.morphologyEx(cleaned, cv2.MORPH_CLOSE, kernel, iterations=2)

    contour = _largest_contour(cleaned)
    if contour is None:
        return cleaned, None

    final_mask = np.zeros_like(cleaned)
    cv2.drawContours(final_mask, [contour], -1, 255, thickness=cv2.FILLED)

    return final_mask, contour


# -----------------------------
# A — Asymmetry
# -----------------------------
def compute_asymmetry(mask: np.ndarray) -> FeatureResult:
    ys, xs = np.where(mask > 0)
    if len(xs) == 0:
        return FeatureResult(0.0, "not assessable", ["asymmetry not assessable"], {})

    x1, x2 = xs.min(), xs.max()
    y1, y2 = ys.min(), ys.max()

    lesion_crop = mask[y1:y2 + 1, x1:x2 + 1]
    h, w = lesion_crop.shape

    if w % 2 != 0:
        lesion_crop = np.pad(lesion_crop, ((0, 0), (0, 1)))
        w += 1
    if h % 2 != 0:
        lesion_crop = np.pad(lesion_crop, ((0, 1), (0, 0)))
        h += 1

    left = lesion_crop[:, : w // 2]
    right = cv2.flip(lesion_crop[:, w // 2:], 1)

    top = lesion_crop[: h // 2, :]
    bottom = cv2.flip(lesion_crop[h // 2:, :], 0)

    lr_ratio = np.sum(left != right) / max(left.size, 1)
    tb_ratio = np.sum(top != bottom) / max(top.size, 1)

    asymmetry_raw = (lr_ratio + tb_ratio) / 2
    score = _normalise_score(asymmetry_raw, 0.05, 0.45)

    if score < 0.33:
        return FeatureResult(score, "low asymmetry",
                             ["low asymmetry", "balanced structure", "symmetrical appearance"], {})
    elif score < 0.66:
        return FeatureResult(score, "moderate asymmetry",
                             ["moderate asymmetry", "some imbalance", "slightly uneven"], {})
    else:
        return FeatureResult(score, "marked asymmetry",
                             ["marked asymmetry", "clearly uneven", "strong imbalance"], {})


# -----------------------------
# B — Border
# -----------------------------
def compute_border_irregularity(contour: np.ndarray) -> FeatureResult:
    area = cv2.contourArea(contour)
    perimeter = cv2.arcLength(contour, True)

    circularity = (4 * np.pi * area) / (perimeter ** 2 + 1e-6)

    hull = cv2.convexHull(contour)
    solidity = area / (cv2.contourArea(hull) + 1e-6)

    irregularity_raw = ((1 - circularity) * 0.7) + ((1 - solidity) * 0.3)
    score = _normalise_score(irregularity_raw, 0.05, 0.55)

    if score < 0.33:
        return FeatureResult(score, "regular border",
                             ["smooth border", "well-defined edge", "uniform outline"], {})
    elif score < 0.66:
        return FeatureResult(score, "mildly irregular border",
                             ["slightly uneven border", "minor irregularity"], {})
    else:
        return FeatureResult(score, "irregular border",
                             ["irregular border", "jagged edge", "non-uniform outline"], {})


# -----------------------------
# C — Colour
# -----------------------------
def compute_colour_variation(image_bgr: np.ndarray, mask: np.ndarray) -> FeatureResult:
    lab = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2LAB)
    lesion = lab[mask > 0]

    if len(lesion) < 20:
        return FeatureResult(0.0, "not assessable", ["colour not assessable"], {})

    l_std = np.std(lesion[:, 0])
    a_std = np.std(lesion[:, 1])
    b_std = np.std(lesion[:, 2])

    combined = (l_std * 0.4) + (a_std * 0.3) + (b_std * 0.3)
    score = _normalise_score(combined, 8.0, 35.0)

    if score < 0.33:
        return FeatureResult(score, "low colour variation",
                             ["uniform colour", "consistent pigmentation"], {})
    elif score < 0.66:
        return FeatureResult(score, "moderate colour variation",
                             ["some variation", "non-uniform colour"], {})
    else:
        return FeatureResult(score, "high colour variation",
                             ["multiple colours", "diverse pigmentation"], {})


# -----------------------------
# Keyword bank
# -----------------------------
def build_keyword_bank(a, b, c):
    return {
        "asymmetry": a.keywords,
        "border": b.keywords,
        "colour": c.keywords,
        "pooled": a.keywords + b.keywords + c.keywords
    }


# -----------------------------
# Main ABC pipeline
# -----------------------------
def analyse_abc_features(image_bgr: np.ndarray) -> dict:
    mask, contour = segment_lesion(image_bgr)

    if contour is None:
        return {
            "success": False,
            "message": "Lesion could not be isolated."
        }

    a = compute_asymmetry(mask)
    b = compute_border_irregularity(contour)
    c = compute_colour_variation(image_bgr, mask)

    return {
        "success": True,
        "asymmetry": a.__dict__,
        "border": b.__dict__,
        "colour": c.__dict__,
        "keyword_bank": build_keyword_bank(a, b, c)
    }


# -----------------------------
# Baseline explanation generator
# -----------------------------
def build_baseline_abc_explanation(abc_result: dict) -> str:
    if not abc_result.get("success"):
        return "The lesion could not be reliably analysed."

    a = abc_result["asymmetry"]["label"]
    b = abc_result["border"]["label"]
    c = abc_result["colour"]["label"]

    if "low" in a and "regular" in b and "low" in c:
        return (
            "The lesion appears symmetrical with a smooth border and consistent colour, "
            "indicating a relatively uniform structure."
        )

    if "marked" in a or "irregular" in b or "high" in c:
        return (
            "The lesion shows asymmetry, border irregularity, and colour variation, "
            "suggesting structural and pigmentation inconsistencies."
        )

    return f"The lesion shows {a}, {b}, and {c}."
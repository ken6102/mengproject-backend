from __future__ import annotations

from dataclasses import dataclass
from typing import Any
import cv2
import numpy as np


@dataclass
class FeatureResult:
    score: float
    label: str
    keywords: list[str]
    details: dict[str, Any]


def _normalise_score(value: float, min_value: float, max_value: float) -> float:
    if max_value <= min_value:
        return 0.0
    clipped = max(min_value, min(value, max_value))
    return (clipped - min_value) / (max_value - min_value)


def _largest_contour(mask: np.ndarray) -> np.ndarray | None:
    contours, _ = cv2.findContours(
        mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
    )
    if not contours:
        return None
    return max(contours, key=cv2.contourArea)


def _resize_for_analysis(image_bgr: np.ndarray, target_width: int = 384) -> np.ndarray:
    h, w = image_bgr.shape[:2]
    if w <= target_width:
        return image_bgr.copy()

    scale = target_width / w
    new_w = int(w * scale)
    new_h = int(h * scale)

    return cv2.resize(image_bgr, (new_w, new_h), interpolation=cv2.INTER_AREA)


def segment_lesion(image_bgr: np.ndarray) -> tuple[np.ndarray, np.ndarray | None]:
    """
    Segments the lesion from the provided image.
    IMPORTANT:
    - Expects image_bgr already resized/prepared for analysis.
    - Returns a mask with the SAME height/width as image_bgr.
    """
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


def compute_asymmetry(mask: np.ndarray) -> FeatureResult:
    ys, xs = np.where(mask > 0)
    if len(xs) == 0 or len(ys) == 0:
        return FeatureResult(
            score=0.0,
            label="not assessable",
            keywords=["asymmetry not assessable"],
            details={},
        )

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
    right = lesion_crop[:, w // 2 :]
    right_flipped = cv2.flip(right, 1)

    top = lesion_crop[: h // 2, :]
    bottom = lesion_crop[h // 2 :, :]
    bottom_flipped = cv2.flip(bottom, 0)

    lr_diff = np.sum(left != right_flipped)
    tb_diff = np.sum(top != bottom_flipped)

    lr_ratio = lr_diff / max(left.size, 1)
    tb_ratio = tb_diff / max(top.size, 1)

    asymmetry_raw = (lr_ratio + tb_ratio) / 2.0
    asymmetry_score = _normalise_score(asymmetry_raw, 0.05, 0.45)

    if asymmetry_score < 0.33:
        label = "low asymmetry"
        keywords = [
            "low asymmetry",
            "largely balanced structure",
            "relatively symmetrical appearance",
        ]
    elif asymmetry_score < 0.66:
        label = "moderate asymmetry"
        keywords = [
            "moderate asymmetry",
            "some structural imbalance",
            "mildly uneven shape",
        ]
    else:
        label = "marked asymmetry"
        keywords = [
            "marked asymmetry",
            "clearly uneven structure",
            "pronounced structural imbalance",
        ]

    return FeatureResult(
        score=float(asymmetry_score),
        label=label,
        keywords=keywords,
        details={
            "left_right_difference_ratio": float(lr_ratio),
            "top_bottom_difference_ratio": float(tb_ratio),
            "bounding_box": [int(x1), int(y1), int(x2), int(y2)],
        },
    )


def compute_border_irregularity(contour: np.ndarray) -> FeatureResult:
    area = cv2.contourArea(contour)
    perimeter = cv2.arcLength(contour, True)

    if area <= 0 or perimeter <= 0:
        return FeatureResult(
            score=0.0,
            label="not assessable",
            keywords=["border not assessable"],
            details={},
        )

    circularity = (4.0 * np.pi * area) / (perimeter * perimeter + 1e-6)

    hull = cv2.convexHull(contour)
    hull_area = cv2.contourArea(hull)
    solidity = area / max(hull_area, 1e-6)

    irregularity_raw = ((1.0 - circularity) * 0.7) + ((1.0 - solidity) * 0.3)
    irregularity_score = _normalise_score(irregularity_raw, 0.05, 0.55)

    if irregularity_score < 0.33:
        label = "regular border"
        keywords = [
            "regular border",
            "well-defined outline",
            "smooth lesion margin",
        ]
    elif irregularity_score < 0.66:
        label = "mildly irregular border"
        keywords = [
            "mildly irregular border",
            "slightly uneven outline",
            "some border irregularity",
        ]
    else:
        label = "irregular border"
        keywords = [
            "irregular border",
            "uneven lesion outline",
            "jagged or non-uniform margin",
        ]

    return FeatureResult(
        score=float(irregularity_score),
        label=label,
        keywords=keywords,
        details={
            "area": float(area),
            "perimeter": float(perimeter),
            "circularity": float(circularity),
            "solidity": float(solidity),
        },
    )


def compute_colour_variation(image_bgr: np.ndarray, mask: np.ndarray) -> FeatureResult:
    """
    IMPORTANT:
    - image_bgr and mask MUST have matching height/width
    """
    if image_bgr.shape[:2] != mask.shape[:2]:
        raise ValueError(
            f"Image/mask shape mismatch in colour analysis: "
            f"image={image_bgr.shape[:2]}, mask={mask.shape[:2]}"
        )

    lesion_pixels = image_bgr[mask > 0]
    if len(lesion_pixels) < 20:
        return FeatureResult(
            score=0.0,
            label="not assessable",
            keywords=["colour variation not assessable"],
            details={},
        )

    lab = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2LAB)
    lesion_lab = lab[mask > 0].astype(np.float32)

    l_std = float(np.std(lesion_lab[:, 0]))
    a_std = float(np.std(lesion_lab[:, 1]))
    b_std = float(np.std(lesion_lab[:, 2]))

    combined_std = (l_std * 0.4) + (a_std * 0.3) + (b_std * 0.3)

    sample = lesion_lab
    if len(sample) > 2000:
        indices = np.random.choice(len(sample), 2000, replace=False)
        sample = sample[indices]

    k = min(3, len(sample))
    if k < 2:
        cluster_spread = 0.0
    else:
        criteria = (
            cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER,
            20,
            1.0,
        )
        _, _, centers = cv2.kmeans(
            sample,
            k,
            None,
            criteria,
            5,
            cv2.KMEANS_PP_CENTERS,
        )

        dists = []
        for i in range(len(centers)):
            for j in range(i + 1, len(centers)):
                dists.append(np.linalg.norm(centers[i] - centers[j]))
        cluster_spread = float(np.mean(dists)) if dists else 0.0

    colour_raw = (combined_std * 0.6) + (cluster_spread * 0.4)
    colour_score = _normalise_score(colour_raw, 8.0, 35.0)

    if colour_score < 0.33:
        label = "low colour variation"
        keywords = [
            "low colour variation",
            "fairly uniform pigmentation",
            "consistent colour pattern",
        ]
    elif colour_score < 0.66:
        label = "moderate colour variation"
        keywords = [
            "moderate colour variation",
            "some pigmentation diversity",
            "non-uniform colouring",
        ]
    else:
        label = "high colour variation"
        keywords = [
            "high colour variation",
            "multiple pigmentation tones",
            "marked colour diversity",
        ]

    return FeatureResult(
        score=float(colour_score),
        label=label,
        keywords=keywords,
        details={
            "l_std": l_std,
            "a_std": a_std,
            "b_std": b_std,
            "combined_std": float(combined_std),
            "cluster_spread": float(cluster_spread),
        },
    )


def build_keyword_bank(
    asymmetry: FeatureResult,
    border: FeatureResult,
    colour: FeatureResult,
) -> dict[str, list[str]]:
    return {
        "asymmetry": asymmetry.keywords,
        "border": border.keywords,
        "colour": colour.keywords,
        "pooled": asymmetry.keywords + border.keywords + colour.keywords,
    }


def analyse_abc_features(image_bgr: np.ndarray) -> dict[str, Any]:
    """
    Full ABC feature pipeline.
    Uses one consistently sized image throughout to avoid boolean index mismatches.
    """
    analysis_image = _resize_for_analysis(image_bgr)

    mask, contour = segment_lesion(analysis_image)

    if contour is None:
        return {
            "success": False,
            "message": "Could not isolate lesion region from image.",
            "asymmetry": None,
            "border": None,
            "colour": None,
            "keyword_bank": {
                "asymmetry": ["asymmetry not assessable"],
                "border": ["border not assessable"],
                "colour": ["colour variation not assessable"],
                "pooled": [
                    "asymmetry not assessable",
                    "border not assessable",
                    "colour variation not assessable",
                ],
            },
        }

    asymmetry = compute_asymmetry(mask)
    border = compute_border_irregularity(contour)
    colour = compute_colour_variation(analysis_image, mask)

    return {
        "success": True,
        "asymmetry": {
            "score": asymmetry.score,
            "label": asymmetry.label,
            "keywords": asymmetry.keywords,
            "details": asymmetry.details,
        },
        "border": {
            "score": border.score,
            "label": border.label,
            "keywords": border.keywords,
            "details": border.details,
        },
        "colour": {
            "score": colour.score,
            "label": colour.label,
            "keywords": colour.keywords,
            "details": colour.details,
        },
        "keyword_bank": build_keyword_bank(asymmetry, border, colour),
    }


def build_baseline_abc_explanation(abc_result: dict[str, Any]) -> str:
    """
    Generates a simple grounded explanation from the extracted ABC features.
    """
    if not abc_result.get("success", False):
        return (
            "The lesion image could not be reliably analysed for asymmetry, "
            "border, and colour variation."
        )

    a = abc_result["asymmetry"]["label"]
    b = abc_result["border"]["label"]
    c = abc_result["colour"]["label"]

    if "low" in a and "regular" in b and "low" in c:
        return (
            "The lesion appears relatively symmetrical, with a smooth and "
            "well-defined border and minimal colour variation. These features "
            "suggest a more uniform visual appearance."
        )

    if "marked" in a or "irregular" in b or "high" in c:
        return (
            "The lesion demonstrates noticeable asymmetry, border irregularity, "
            "and variation in colour distribution. These image-derived features "
            "suggest visible structural and pigmentation inconsistencies."
        )

    return (
        f"The lesion shows {a}, {b}, and {c}. "
        f"This suggests some degree of structural and visual variation within the lesion."
    )
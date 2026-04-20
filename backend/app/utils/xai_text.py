import os
from openai import OpenAI

client = OpenAI(api_key=os.environ.get("OPENAI_API_KEY"))


def _safe_feature_summary(abc_features: dict | None) -> str:
    if not abc_features:
        return (
            "Asymmetry: not available\n"
            "Border: not available\n"
            "Colour: not available"
        )

    asymmetry = abc_features.get("asymmetry") or {}
    border = abc_features.get("border") or {}
    colour = abc_features.get("colour") or {}

    asymmetry_label = asymmetry.get("label", "not available")
    asymmetry_score = asymmetry.get("score", "not available")

    border_label = border.get("label", "not available")
    border_score = border.get("score", "not available")

    colour_label = colour.get("label", "not available")
    colour_score = colour.get("score", "not available")

    def fmt_score(value):
        if isinstance(value, (int, float)):
            return f"{value:.2f}"
        return "not available"

    return (
        f"Asymmetry: {asymmetry_label} (score: {fmt_score(asymmetry_score)})\n"
        f"Border: {border_label} (score: {fmt_score(border_score)})\n"
        f"Colour: {colour_label} (score: {fmt_score(colour_score)})"
    )


def rewrite_abc_explanation(
    baseline_text: str,
    keyword_bank: dict,
    abc_features: dict | None = None,
    label: str | None = None,
    confidence: float | None = None,
) -> str:
    pooled_keywords = keyword_bank.get("pooled", []) if keyword_bank else []
    keyword_text = ", ".join(pooled_keywords) if pooled_keywords else "None"

    label_text = label or "unknown"
    confidence_text = (
        f"{confidence * 100:.1f}%"
        if isinstance(confidence, (int, float))
        else "unknown"
    )

    abc_summary = _safe_feature_summary(abc_features)

    prompt = f"""
You are rewriting a grounded explainability summary for a GP-facing skin lesion screening prototype.

Your task:
Turn the supplied image-analysis findings into a more detailed, polished explanation suitable for a clinician-facing prototype result screen.

Important rules:
- Do not invent any new visual findings, diagnoses, or clinical facts.
- Only use the supplied prediction, baseline explanation, ABC feature labels/scores, and keywords.
- You may provide cautious clinical-style interpretation, but you must not present a definitive diagnosis.
- Do not say the lesion definitely is benign or definitely is malignant.
- Use wording such as "appears", "may be consistent with", "image-derived features suggest", "would warrant", or "is relatively reassuring" where appropriate.
- Keep the tone professional, concise, and medically literate.
- Avoid excessive repetition of the same ABC terms.
- Make the output more detailed than the baseline.
- Write 5 to 8 sentences total.
- Return plain text only.

Preferred structure:
1. Start with a brief overall assessment linked to the model output and confidence.
2. Explain what the image-derived ABC features suggest in plain but clinical wording.
3. End with a cautious practical interpretation, such as whether the pattern appears more reassuring or whether it may justify closer review.
4. Do not include bullet points.

Model prediction label: {label_text}
Model confidence: {confidence_text}

ABC feature summary:
{abc_summary}

Keyword bank:
{keyword_text}

Baseline explanation:
{baseline_text}
""".strip()

    try:
        response = client.responses.create(
            model="gpt-5.4",
            input=prompt,
        )
        rewritten = response.output_text.strip()
        return rewritten if rewritten else baseline_text
    except Exception:
        return baseline_text
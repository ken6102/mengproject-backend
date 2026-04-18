import os
from openai import OpenAI

client = OpenAI(api_key=os.environ.get("OPENAI_API_KEY"))


def rewrite_abc_explanation(
    baseline_text: str,
    keyword_bank: dict,
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

    prompt = f"""
You are rewriting a grounded dermatology explanation for a GP-facing prototype app.

Rules:
- Do not add any new findings, diagnoses, or interpretations.
- Do not mention features that are not already present in the supplied text or keywords.
- Keep the wording concise, professional, and cautious.
- Keep the explanation to 2-4 sentences.
- Do not claim certainty.
- Preserve the meaning of the baseline explanation.

Model prediction label: {label_text}
Model confidence: {confidence_text}

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
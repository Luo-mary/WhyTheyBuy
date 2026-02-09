"""
Language utilities for AI response localization.

This module provides language detection and formatting for AI-generated content.
"""

from typing import Optional

# Supported languages with their full names
SUPPORTED_LANGUAGES = {
    "en": "English",
    "zh": "Chinese (Simplified)",
    "zh-CN": "Chinese (Simplified)",
    "zh-TW": "Chinese (Traditional)",
    "es": "Spanish",
    "ja": "Japanese",
    "ko": "Korean",
    "de": "German",
    "fr": "French",
    "ar": "Arabic",
    "pt": "Portuguese",
    "ru": "Russian",
    "it": "Italian",
}

# Default language
DEFAULT_LANGUAGE = "en"


def get_language_name(code: str) -> str:
    """
    Get the full language name from a language code.

    Args:
        code: ISO 639-1 language code (e.g., "en", "zh", "es")

    Returns:
        Full language name (e.g., "English", "Chinese (Simplified)")
    """
    # Handle locale codes like "en-US" or "zh-CN"
    base_code = code.split("-")[0].lower() if code else DEFAULT_LANGUAGE

    # Check exact match first, then base code
    if code in SUPPORTED_LANGUAGES:
        return SUPPORTED_LANGUAGES[code]
    elif base_code in SUPPORTED_LANGUAGES:
        return SUPPORTED_LANGUAGES[base_code]
    else:
        return SUPPORTED_LANGUAGES[DEFAULT_LANGUAGE]


def normalize_language_code(code: Optional[str]) -> str:
    """
    Normalize a language code to a supported format.

    Args:
        code: Raw language code from request

    Returns:
        Normalized language code
    """
    if not code:
        return DEFAULT_LANGUAGE

    # Handle common variations
    code = code.strip().lower()

    # Handle locale codes
    if "-" in code:
        parts = code.split("-")
        # For Chinese, preserve the region
        if parts[0] == "zh":
            return code
        return parts[0]

    return code if code in SUPPORTED_LANGUAGES else DEFAULT_LANGUAGE


def get_language_instruction(language_code: str) -> str:
    """
    Get the AI instruction for responding in a specific language.

    Args:
        language_code: ISO 639-1 language code

    Returns:
        Instruction string for the AI to respond in the specified language
    """
    lang_name = get_language_name(language_code)

    if language_code == "en" or language_code.startswith("en"):
        return ""  # No special instruction needed for English

    return f"""
LANGUAGE REQUIREMENT:
You MUST respond entirely in {lang_name}.
- All analysis, observations, and conclusions must be written in {lang_name}.
- Technical terms and company names can remain in English, but explanations must be in {lang_name}.
- Disclaimers and warnings must also be in {lang_name}.
- Do NOT respond in English unless the text is a proper noun or technical term.
"""


def get_localized_disclaimer(language_code: str) -> str:
    """
    Get the disclaimer text in the specified language.

    Args:
        language_code: ISO 639-1 language code

    Returns:
        Disclaimer text in the specified language
    """
    disclaimers = {
        "en": "This is not investment advice. This analysis is for informational purposes only.",
        "zh": "这不是投资建议。此分析仅供参考。",
        "es": "Esto no es asesoramiento de inversiones. Este analisis es solo para fines informativos.",
        "ja": "これは投資アドバイスではありません。この分析は情報提供のみを目的としています。",
        "ko": "이것은 투자 조언이 아닙니다. 이 분석은 정보 제공 목적으로만 제공됩니다.",
        "de": "Dies ist keine Anlageberatung. Diese Analyse dient nur zu Informationszwecken.",
        "fr": "Ceci n'est pas un conseil en investissement. Cette analyse est fournie a titre informatif uniquement.",
        "ar": "هذه ليست نصيحة استثمارية. هذا التحليل لاغراض المعلومات فقط.",
    }

    base_code = normalize_language_code(language_code)
    return disclaimers.get(base_code, disclaimers["en"])


def is_rtl_language(language_code: str) -> bool:
    """
    Check if a language is right-to-left.

    Args:
        language_code: ISO 639-1 language code

    Returns:
        True if the language is RTL
    """
    rtl_languages = {"ar", "he", "fa", "ur"}
    base_code = normalize_language_code(language_code)
    return base_code in rtl_languages

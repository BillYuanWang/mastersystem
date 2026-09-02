#!/usr/bin/env python3
"""Render the macOS employee guide and UAT checklist as a navigable PDF."""

from __future__ import annotations

import hashlib
from pathlib import Path

from build_tutorial_pdf import (
    ManualDocTemplate,
    make_styles,
    markdown_story,
    register_fonts,
    source_metadata,
)


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "MD_DESK_EMPLOYEE_GUIDE.md"
OUTPUT = ROOT / "MD_DESK_EMPLOYEE_GUIDE.pdf"


def main() -> None:
    register_fonts()
    source = SOURCE.read_text(encoding="utf-8")
    version, updated = source_metadata(source)
    source_hash = hashlib.sha256(source.encode("utf-8")).hexdigest()[:16]
    styles = make_styles()
    doc = ManualDocTemplate(
        str(OUTPUT),
        version=version,
        updated=updated,
        source_hash=source_hash,
        document_title="MD Desk macOS 员工使用说明与功能验收清单",
        running_header="MD DESK · 员工使用与功能验收清单",
        source_name=SOURCE.name,
    )
    doc.build(markdown_story(source, doc, styles))
    print(f"Built {OUTPUT.name} from {SOURCE.name} ({version}, sha256:{source_hash})")


if __name__ == "__main__":
    main()

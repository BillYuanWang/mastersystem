#!/usr/bin/env python3
"""Render the root administrator tutorial Markdown as a navigable PDF."""

from __future__ import annotations

import hashlib
import html
import re
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    HRFlowable,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "TUTORIAL.md"
OUTPUT = ROOT / "TUTORIAL.pdf"

INK = colors.HexColor("#1D2025")
MUTED = colors.HexColor("#66707A")
ACCENT = colors.HexColor("#0A72E8")
ACCENT_SOFT = colors.HexColor("#EAF3FF")
SURFACE = colors.HexColor("#F4F6F8")
SEPARATOR = colors.HexColor("#D8DEE5")
WHITE = colors.white

FONT_REGULAR = "MDHeiti"
FONT_BOLD = "MDHeitiMedium"


def register_fonts() -> None:
    regular = Path("/System/Library/Fonts/STHeiti Light.ttc")
    bold = Path("/System/Library/Fonts/STHeiti Medium.ttc")
    fallback = Path("/System/Library/Fonts/Supplemental/Arial Unicode.ttf")

    if regular.exists() and bold.exists():
        pdfmetrics.registerFont(TTFont(FONT_REGULAR, str(regular), subfontIndex=0))
        pdfmetrics.registerFont(TTFont(FONT_BOLD, str(bold), subfontIndex=0))
    elif fallback.exists():
        pdfmetrics.registerFont(TTFont(FONT_REGULAR, str(fallback)))
        pdfmetrics.registerFont(TTFont(FONT_BOLD, str(fallback)))
    else:
        raise RuntimeError("A Chinese-capable system font is required to build TUTORIAL.pdf")


def source_metadata(source: str) -> tuple[str, str]:
    version_match = re.search(r"适用版本：\s*([^*\n]+)", source)
    date_match = re.search(r"更新日期：\s*([^*\n]+)", source)
    version = version_match.group(1).strip() if version_match else "current"
    updated = date_match.group(1).strip() if date_match else ""
    return version, updated


def slugify(value: str) -> str:
    value = re.sub(r"[`*_]", "", value.strip().lower())
    value = re.sub(r"[^0-9a-z\u3400-\u9fff]+", "-", value)
    return value.strip("-") or "section"


def inline_markup(value: str) -> str:
    escaped = html.escape(value.strip())
    escaped = re.sub(
        r"\[([^\]]+)\]\(([^)]+)\)",
        lambda match: (
            f'<link href="{html.escape(match.group(2), quote=True)}" '
            f'color="{ACCENT.hexval()}">{match.group(1)}</link>'
        ),
        escaped,
    )
    escaped = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", escaped)
    escaped = re.sub(
        r"`([^`]+)`",
        rf'<font name="{FONT_BOLD}" color="#3F4852">\1</font>',
        escaped,
    )
    return escaped


def is_table_separator(line: str) -> bool:
    cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
    return bool(cells) and all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells)


def parse_table_row(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


class ManualDocTemplate(BaseDocTemplate):
    def __init__(self, filename: str, *, version: str, updated: str, source_hash: str) -> None:
        self.version = version
        self.updated = updated
        self.source_hash = source_hash
        super().__init__(
            filename,
            pagesize=A4,
            leftMargin=18 * mm,
            rightMargin=18 * mm,
            topMargin=19 * mm,
            bottomMargin=18 * mm,
            title="MD Desk 教务老师使用手册",
            author="Starton EDU Irvine, Inc. & Master Dance",
            subject=f"Generated from TUTORIAL.md sha256:{source_hash}",
        )
        frame = Frame(
            self.leftMargin,
            self.bottomMargin,
            self.width,
            self.height,
            id="manual",
            leftPadding=0,
            rightPadding=0,
            topPadding=0,
            bottomPadding=0,
        )
        self.addPageTemplates([PageTemplate(id="manual", frames=[frame], onPage=self.draw_page)])

    def draw_page(self, canvas, doc) -> None:
        canvas.saveState()
        canvas.setTitle("MD Desk 教务老师使用手册")
        canvas.setAuthor("Starton EDU Irvine, Inc. & Master Dance")
        canvas.setSubject(f"TUTORIAL.md sha256:{self.source_hash}")
        page = canvas.getPageNumber()
        if page > 1:
            canvas.setFont(FONT_BOLD, 7.7)
            canvas.setFillColor(MUTED)
            canvas.drawString(self.leftMargin, A4[1] - 11 * mm, "MD DESK · 教务老师使用手册")
            canvas.drawRightString(A4[0] - self.rightMargin, A4[1] - 11 * mm, self.version)
            canvas.setStrokeColor(SEPARATOR)
            canvas.setLineWidth(0.45)
            canvas.line(self.leftMargin, A4[1] - 13.5 * mm, A4[0] - self.rightMargin, A4[1] - 13.5 * mm)

        canvas.setStrokeColor(SEPARATOR)
        canvas.setLineWidth(0.45)
        canvas.line(self.leftMargin, 12 * mm, A4[0] - self.rightMargin, 12 * mm)
        canvas.setFont(FONT_REGULAR, 7.6)
        canvas.setFillColor(MUTED)
        canvas.drawString(self.leftMargin, 7.5 * mm, "Starton EDU Irvine, Inc. & Master Dance")
        canvas.drawRightString(A4[0] - self.rightMargin, 7.5 * mm, f"第 {page} 页")
        canvas.restoreState()

    def afterFlowable(self, flowable) -> None:
        anchor = getattr(flowable, "md_anchor", None)
        if not anchor:
            return
        level = getattr(flowable, "md_level", 0)
        title = getattr(flowable, "md_title", anchor)
        self.canv.bookmarkPage(anchor)
        self.canv.addOutlineEntry(title, anchor, level=max(0, level), closed=level > 0)


def make_styles():
    sample = getSampleStyleSheet()
    body = ParagraphStyle(
        "Body",
        parent=sample["BodyText"],
        fontName=FONT_REGULAR,
        fontSize=9.6,
        leading=14.3,
        textColor=INK,
        alignment=TA_LEFT,
        spaceAfter=5.2,
        splitLongWords=True,
        allowWidows=0,
        allowOrphans=0,
    )
    return {
        "body": body,
        "cover_eyebrow": ParagraphStyle(
            "CoverEyebrow",
            parent=body,
            fontName=FONT_BOLD,
            fontSize=9,
            leading=12,
            textColor=ACCENT,
            spaceAfter=14,
        ),
        "h1": ParagraphStyle(
            "Heading1",
            parent=body,
            fontName=FONT_BOLD,
            fontSize=25,
            leading=33,
            textColor=INK,
            spaceAfter=17,
        ),
        "h2": ParagraphStyle(
            "Heading2",
            parent=body,
            fontName=FONT_BOLD,
            fontSize=16.5,
            leading=22,
            textColor=INK,
            spaceBefore=12,
            spaceAfter=8,
            keepWithNext=True,
        ),
        "h3": ParagraphStyle(
            "Heading3",
            parent=body,
            fontName=FONT_BOLD,
            fontSize=12.1,
            leading=17,
            textColor=ACCENT,
            spaceBefore=8,
            spaceAfter=4.5,
            keepWithNext=True,
        ),
        "h4": ParagraphStyle(
            "Heading4",
            parent=body,
            fontName=FONT_BOLD,
            fontSize=10.4,
            leading=15,
            textColor=INK,
            spaceBefore=6,
            spaceAfter=3,
            keepWithNext=True,
        ),
        "bullet": ParagraphStyle(
            "Bullet",
            parent=body,
            leftIndent=15,
            firstLineIndent=-9,
            bulletIndent=2,
            spaceAfter=3.2,
        ),
        "number": ParagraphStyle(
            "Number",
            parent=body,
            leftIndent=19,
            firstLineIndent=-14,
            bulletIndent=0,
            spaceAfter=3.2,
        ),
        "table": ParagraphStyle(
            "TableBody",
            parent=body,
            fontSize=8.2,
            leading=11.4,
            spaceAfter=0,
        ),
        "table_header": ParagraphStyle(
            "TableHeader",
            parent=body,
            fontName=FONT_BOLD,
            fontSize=8.2,
            leading=11.4,
            textColor=WHITE,
            spaceAfter=0,
        ),
        "callout": ParagraphStyle(
            "Callout",
            parent=body,
            fontSize=9.2,
            leading=14,
            spaceAfter=0,
        ),
        "cover_meta": ParagraphStyle(
            "CoverMeta",
            parent=body,
            fontName=FONT_BOLD,
            fontSize=10,
            leading=15,
            textColor=MUTED,
            spaceAfter=2,
        ),
    }


def table_widths(column_count: int, available_width: float) -> list[float]:
    if column_count == 2:
        ratios = [0.31, 0.69]
    elif column_count == 3:
        ratios = [0.25, 0.25, 0.50]
    else:
        ratios = [1 / column_count] * column_count
    return [available_width * ratio for ratio in ratios]


def markdown_story(source: str, doc: ManualDocTemplate, styles) -> list:
    lines = source.splitlines()
    story: list = []
    paragraph_lines: list[str] = []
    pending_anchor: str | None = None
    used_anchors: dict[str, int] = {}
    first_heading = True
    hard_page_break_count = 0
    index = 0

    def flush_paragraph() -> None:
        if not paragraph_lines:
            return
        value = " ".join(part.strip() for part in paragraph_lines).strip()
        paragraph_lines.clear()
        if value:
            story.append(Paragraph(inline_markup(value), styles["body"]))

    def unique_anchor(value: str) -> str:
        count = used_anchors.get(value, 0)
        used_anchors[value] = count + 1
        return value if count == 0 else f"{value}-{count + 1}"

    while index < len(lines):
        raw = lines[index]
        stripped = raw.strip()

        anchor_match = re.fullmatch(r'<a\s+id="([^"]+)"\s*></a>', stripped)
        if anchor_match:
            flush_paragraph()
            pending_anchor = anchor_match.group(1)
            index += 1
            continue

        if stripped == "<!-- PAGE_BREAK -->":
            flush_paragraph()
            # Keep the cover and contents as clean standalone pages. Later
            # chapter markers become spacing so a trailing navigation link can
            # never be pushed onto an otherwise blank page.
            if hard_page_break_count < 2:
                story.append(PageBreak())
            else:
                story.append(Spacer(1, 7))
            hard_page_break_count += 1
            index += 1
            continue

        if stripped.startswith("<!--"):
            flush_paragraph()
            index += 1
            continue

        if stripped == "[回到顶部](#top)":
            # The PDF outline already provides top-level navigation. Omitting
            # this final Markdown-only link prevents a one-line trailing page.
            flush_paragraph()
            index += 1
            continue

        heading_match = re.match(r"^(#{1,4})\s+(.+)$", stripped)
        if heading_match:
            flush_paragraph()
            level = len(heading_match.group(1))
            title = heading_match.group(2).strip()
            if first_heading:
                story.append(Spacer(1, 21 * mm))
                story.append(Paragraph("MASTER DANCE · MD DESK", styles["cover_eyebrow"]))
            anchor = unique_anchor(pending_anchor or slugify(title))
            pending_anchor = None
            heading = Paragraph(inline_markup(title), styles[f"h{level}"])
            heading.md_anchor = anchor
            heading.md_level = level - 1
            heading.md_title = re.sub(r"[*`]", "", title)
            story.append(heading)
            if first_heading:
                story.append(HRFlowable(width="100%", thickness=1.2, color=ACCENT, spaceAfter=13))
                first_heading = False
            index += 1
            continue

        if stripped == "---":
            flush_paragraph()
            story.append(HRFlowable(width="100%", thickness=0.6, color=SEPARATOR, spaceBefore=6, spaceAfter=8))
            index += 1
            continue

        if stripped.startswith(">"):
            flush_paragraph()
            quote_lines: list[str] = []
            while index < len(lines) and lines[index].strip().startswith(">"):
                quote_lines.append(lines[index].strip()[1:].strip())
                index += 1
            quote = Paragraph(inline_markup(" ".join(quote_lines)), styles["callout"])
            callout = Table([["", quote]], colWidths=[3.2, doc.width - 3.2], hAlign="LEFT")
            callout.setStyle(
                TableStyle(
                    [
                        ("BACKGROUND", (0, 0), (0, 0), ACCENT),
                        ("BACKGROUND", (1, 0), (1, 0), ACCENT_SOFT),
                        ("LEFTPADDING", (0, 0), (-1, -1), 0),
                        ("RIGHTPADDING", (0, 0), (0, 0), 0),
                        ("LEFTPADDING", (1, 0), (1, 0), 10),
                        ("RIGHTPADDING", (1, 0), (1, 0), 10),
                        ("TOPPADDING", (0, 0), (-1, -1), 9),
                        ("BOTTOMPADDING", (0, 0), (-1, -1), 9),
                        ("VALIGN", (0, 0), (-1, -1), "TOP"),
                    ]
                )
            )
            story.extend([callout, Spacer(1, 7)])
            continue

        if stripped.startswith("|") and index + 1 < len(lines) and is_table_separator(lines[index + 1]):
            flush_paragraph()
            rows = [parse_table_row(stripped)]
            index += 2
            while index < len(lines) and lines[index].strip().startswith("|"):
                rows.append(parse_table_row(lines[index]))
                index += 1
            column_count = max(len(row) for row in rows)
            normalized = [row + [""] * (column_count - len(row)) for row in rows]
            data = []
            for row_index, row in enumerate(normalized):
                style = styles["table_header"] if row_index == 0 else styles["table"]
                data.append([Paragraph(inline_markup(cell), style) for cell in row])
            table = Table(
                data,
                colWidths=table_widths(column_count, doc.width),
                repeatRows=1,
                hAlign="LEFT",
                splitByRow=True,
            )
            table.setStyle(
                TableStyle(
                    [
                        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#263340")),
                        ("BACKGROUND", (0, 1), (-1, -1), WHITE),
                        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [WHITE, SURFACE]),
                        ("GRID", (0, 0), (-1, -1), 0.45, SEPARATOR),
                        ("LEFTPADDING", (0, 0), (-1, -1), 7),
                        ("RIGHTPADDING", (0, 0), (-1, -1), 7),
                        ("TOPPADDING", (0, 0), (-1, -1), 6),
                        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
                        ("VALIGN", (0, 0), (-1, -1), "TOP"),
                    ]
                )
            )
            story.extend([table, Spacer(1, 8)])
            continue

        unordered = re.match(r"^-\s+(.+)$", stripped)
        numbered = re.match(r"^(\d+)\.\s+(.+)$", stripped)
        if unordered or numbered:
            flush_paragraph()
            if unordered:
                story.append(Paragraph(inline_markup(unordered.group(1)), styles["bullet"], bulletText="•"))
            else:
                story.append(
                    Paragraph(
                        inline_markup(numbered.group(2)),
                        styles["number"],
                        bulletText=f"{numbered.group(1)}.",
                    )
                )
            index += 1
            continue

        if not stripped:
            flush_paragraph()
            index += 1
            continue

        if raw.endswith("  "):
            flush_paragraph()
            story.append(Paragraph(inline_markup(raw.rstrip()), styles["cover_meta"]))
            index += 1
            continue

        paragraph_lines.append(stripped)
        index += 1

    flush_paragraph()
    return story


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
    )
    story = markdown_story(source, doc, styles)
    doc.build(story)
    print(f"Built {OUTPUT.name} from {SOURCE.name} ({version}, sha256:{source_hash})")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Generate the Master Dance agreement PDF and App-ready plain text.

The Markdown between APP-START and APP-END is the canonical signed body.
The PDF embeds Inter and Source Han Sans CN so its typography is reproducible,
searchable, and close to the SF Pro / PingFang proportions used by the apps.
"""

from __future__ import annotations

import argparse
import html
import re
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
from reportlab.platypus import (
    HRFlowable,
    Image,
    KeepTogether,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

PAGE_WIDTH, PAGE_HEIGHT = letter
RAYCAST_RED = colors.HexColor("#FF6363")
RAYCAST_RED_DARK = colors.HexColor("#C83F49")
INK = colors.HexColor("#1F2023")
MUTED = colors.HexColor("#717178")
QUIET = colors.HexColor("#9A9AA1")
SURFACE = colors.HexColor("#F5F5F6")
SURFACE_2 = colors.HexColor("#FAFAFA")
RED_SOFT = colors.HexColor("#FFF0F1")
LINE = colors.HexColor("#E8E8EB")

VERSION = "MD-2026.08-LR1"
AGREEMENT_TITLE = "Master Dance 学员注册、课程服务与安全协议"
ENGLISH_TITLE = "Student Registration, Course Services, and Participation Agreement"
ENTITY = "Starton EDU Irvine, Inc. · Master Dance / 尔湾佳美舞蹈"


REGULAR_FONT = "MDSourceHanRegular"
BOLD_FONT = "MDSourceHanBold"
LATIN_REGULAR_FONT = "MDInterRegular"
LATIN_BOLD_FONT = "MDInterSemiBold"


def register_fonts(font_dir: Path) -> None:
    font_paths = {
        REGULAR_FONT: font_dir / "SourceHanSansCN-Regular.ttf",
        BOLD_FONT: font_dir / "SourceHanSansCN-Bold.ttf",
        LATIN_REGULAR_FONT: font_dir / "Inter-Regular.ttf",
        LATIN_BOLD_FONT: font_dir / "Inter-SemiBold.ttf",
    }
    missing = [str(path) for path in font_paths.values() if not path.exists()]
    if missing:
        raise FileNotFoundError("Required PDF fonts were not found: " + ", ".join(missing))

    for name, path in font_paths.items():
        pdfmetrics.registerFont(TTFont(name, path, asciiReadable=True, shapable=True))

    pdfmetrics.registerFontFamily(
        "MDSourceHan",
        normal=REGULAR_FONT,
        bold=BOLD_FONT,
        italic=REGULAR_FONT,
        boldItalic=BOLD_FONT,
    )
    pdfmetrics.registerFontFamily(
        "MDInter",
        normal=LATIN_REGULAR_FONT,
        bold=LATIN_BOLD_FONT,
        italic=LATIN_REGULAR_FONT,
        boldItalic=LATIN_BOLD_FONT,
    )


def extract_app_text(source: str) -> str:
    match = re.search(r"<!-- APP-START -->\s*(.*?)\s*<!-- APP-END -->", source, re.S)
    if not match:
        raise ValueError("APP-START / APP-END markers were not found")
    body = match.group(1)
    body = re.sub(r"\*\*(.*?)\*\*", r"\1", body)
    body = re.sub(r"\[(.*?)\]\((https?://[^)]+)\)", r"\1：\2", body)
    body = re.sub(r"^#{1,6}\s+", "", body, flags=re.M)
    body = re.sub(r"[ \t]+$", "", body, flags=re.M)
    body = re.sub(r"\n{3,}", "\n\n", body)
    return body.strip() + "\n"


class AgreementCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states: list[dict] = []
        self.setTitle(AGREEMENT_TITLE)
        self.setAuthor("Starton EDU Irvine, Inc. / Master Dance")
        self.setSubject("Internal legal review draft - not for signature")
        self.setCreator("Master Dance agreement generator")

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        page_count = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self._draw_chrome(page_count)
            super().showPage()
        super().save()

    def _draw_chrome(self, page_count: int):
        page = self._pageNumber
        self.saveState()
        if page > 1:
            self.setStrokeColor(LINE)
            self.setLineWidth(0.55)
            self.line(0.68 * inch, PAGE_HEIGHT - 0.58 * inch, PAGE_WIDTH - 0.68 * inch, PAGE_HEIGHT - 0.58 * inch)
            self.setFont(LATIN_BOLD_FONT, 7.2)
            self.setFillColor(INK)
            self.drawString(0.68 * inch, PAGE_HEIGHT - 0.43 * inch, "MASTER DANCE")
            self.setFont(REGULAR_FONT, 7.2)
            self.setFillColor(QUIET)
            self.drawRightString(PAGE_WIDTH - 0.68 * inch, PAGE_HEIGHT - 0.43 * inch, "学员协议 · INTERNAL LEGAL REVIEW")

        self.setStrokeColor(LINE)
        self.setLineWidth(0.45)
        self.line(0.68 * inch, 0.52 * inch, PAGE_WIDTH - 0.68 * inch, 0.52 * inch)
        self.setFont(LATIN_REGULAR_FONT, 7)
        self.setFillColor(QUIET)
        self.drawString(0.68 * inch, 0.34 * inch, f"{VERSION} · NOT FOR SIGNATURE")
        self.drawRightString(PAGE_WIDTH - 0.68 * inch, 0.34 * inch, f"{page} / {page_count}")
        self.restoreState()


def styles() -> dict[str, ParagraphStyle]:
    base = getSampleStyleSheet()
    return {
        "cover_title": ParagraphStyle(
            "CoverTitle",
            parent=base["Title"],
            fontName=BOLD_FONT,
            fontSize=23.5,
            leading=30.5,
            textColor=INK,
            alignment=TA_CENTER,
            spaceAfter=8,
            wordWrap="CJK",
        ),
        "cover_en": ParagraphStyle(
            "CoverEnglish",
            parent=base["Normal"],
            fontName=LATIN_REGULAR_FONT,
            fontSize=9.8,
            leading=14,
            textColor=MUTED,
            alignment=TA_CENTER,
            wordWrap="CJK",
        ),
        "cover_meta": ParagraphStyle(
            "CoverMeta",
            parent=base["Normal"],
            fontName=REGULAR_FONT,
            fontSize=9.2,
            leading=15,
            textColor=INK,
            alignment=TA_CENTER,
            wordWrap="CJK",
        ),
        "page_title": ParagraphStyle(
            "PageTitle",
            parent=base["Heading1"],
            fontName=BOLD_FONT,
            fontSize=19.5,
            leading=25,
            textColor=INK,
            spaceAfter=10,
            wordWrap="CJK",
        ),
        "section": ParagraphStyle(
            "Section",
            parent=base["Heading2"],
            fontName=BOLD_FONT,
            fontSize=13.4,
            leading=18,
            textColor=INK,
            spaceBefore=10,
            spaceAfter=6,
            keepWithNext=True,
            wordWrap="CJK",
        ),
        "appendix": ParagraphStyle(
            "Appendix",
            parent=base["Heading2"],
            fontName=BOLD_FONT,
            fontSize=15,
            leading=21,
            textColor=INK,
            spaceAfter=10,
            keepWithNext=True,
            wordWrap="CJK",
        ),
        "body": ParagraphStyle(
            "Body",
            parent=base["BodyText"],
            fontName=REGULAR_FONT,
            fontSize=9.7,
            leading=15.25,
            textColor=colors.HexColor("#34353A"),
            spaceAfter=6.2,
            splitLongWords=True,
            wordWrap="CJK",
            allowWidows=0,
            allowOrphans=0,
        ),
        "small": ParagraphStyle(
            "Small",
            parent=base["BodyText"],
            fontName=REGULAR_FONT,
            fontSize=8.3,
            leading=13.4,
            textColor=MUTED,
            spaceAfter=5,
            wordWrap="CJK",
        ),
        "checkbox": ParagraphStyle(
            "Checkbox",
            parent=base["BodyText"],
            fontName=REGULAR_FONT,
            fontSize=9.4,
            leading=14.5,
            leftIndent=12,
            firstLineIndent=-12,
            textColor=colors.HexColor("#34353A"),
            spaceAfter=5,
            wordWrap="CJK",
        ),
        "field": ParagraphStyle(
            "Field",
            parent=base["BodyText"],
            fontName=REGULAR_FONT,
            fontSize=9.1,
            leading=14,
            leftIndent=7,
            rightIndent=7,
            borderColor=SURFACE_2,
            borderWidth=0,
            borderPadding=5,
            backColor=SURFACE_2,
            textColor=colors.HexColor("#3D3E43"),
            spaceAfter=4,
            wordWrap="CJK",
        ),
        "signature_field": ParagraphStyle(
            "SignatureField",
            parent=base["BodyText"],
            fontName=REGULAR_FONT,
            fontSize=9.1,
            leading=14,
            textColor=colors.HexColor("#3D3E43"),
            wordWrap="CJK",
        ),
        "warning": ParagraphStyle(
            "Warning",
            parent=base["BodyText"],
            fontName=REGULAR_FONT,
            fontSize=9.2,
            leading=14.8,
            textColor=colors.HexColor("#82323A"),
            borderWidth=0,
            borderPadding=0,
            backColor=RED_SOFT,
            spaceAfter=10,
            wordWrap="CJK",
        ),
        "waiver": ParagraphStyle(
            "Waiver",
            parent=base["BodyText"],
            fontName=BOLD_FONT,
            fontSize=9.3,
            leading=15,
            textColor=colors.HexColor("#6F2B31"),
            borderWidth=0,
            borderPadding=0,
            backColor=RED_SOFT,
            spaceBefore=5,
            spaceAfter=10,
            wordWrap="CJK",
        ),
        "confirmation": ParagraphStyle(
            "Confirmation",
            parent=base["BodyText"],
            fontName=REGULAR_FONT,
            fontSize=9.3,
            leading=15,
            textColor=colors.HexColor("#393A3F"),
            borderWidth=0,
            borderPadding=0,
            backColor=SURFACE,
            spaceBefore=5,
            spaceAfter=10,
            wordWrap="CJK",
        ),
        "toc": ParagraphStyle(
            "TOC",
            parent=base["BodyText"],
            fontName=REGULAR_FONT,
            fontSize=8.7,
            leading=13.5,
            textColor=colors.HexColor("#34353A"),
            leftIndent=8,
            spaceAfter=2.5,
            wordWrap="CJK",
        ),
        "right": ParagraphStyle(
            "Right",
            parent=base["BodyText"],
            fontName=REGULAR_FONT,
            fontSize=8.5,
            leading=13.5,
            textColor=MUTED,
            alignment=TA_LEFT,
            wordWrap="CJK",
        ),
    }


def esc(text: str) -> str:
    return html.escape(text, quote=False)


def rich(text: str, *, bold: bool = False) -> str:
    """Use Inter for Latin runs and Source Han Sans for CJK runs."""

    latin_font = LATIN_BOLD_FONT if bold else LATIN_REGULAR_FONT
    cjk_font = BOLD_FONT if bold else REGULAR_FONT
    runs: list[tuple[bool, str]] = []

    for character in text:
        latin = ord(character) < 0x2E80
        if character.isspace() and runs:
            latin = runs[-1][0]
        if runs and runs[-1][0] == latin:
            runs[-1] = (latin, runs[-1][1] + character)
        else:
            runs.append((latin, character))

    return "".join(
        f"<font name='{latin_font if latin else cjk_font}'>{esc(run)}</font>"
        for latin, run in runs
    )


def section_markup(text: str) -> str:
    match = re.match(r"^(\d+\.)(?:\s+)(.*)$", text)
    if not match:
        return rich(text, bold=True)
    return (
        f"<font color='#FF6363'>{rich(match.group(1), bold=True)}</font> "
        + rich(match.group(2), bold=True)
    )


def appendix_markup(text: str) -> str:
    if "：" not in text:
        return rich(text, bold=True)
    label, title = text.split("：", 1)
    return (
        f"<font color='#FF6363'>{rich(label + '：', bold=True)}</font>"
        + rich(title, bold=True)
    )


def field_markup(text: str) -> str:
    if "：" not in text:
        return rich(text)
    label, value = text.split("：", 1)
    return rich(label + "：", bold=True) + rich(value)


def callout(text: str, style: ParagraphStyle, title: str | None = None) -> Table:
    content = rich(text)
    if title:
        content = f"{rich(title, bold=True)}<br/>{content}"
    table = Table(
        [[Paragraph(content, style)]],
        colWidths=[6.78 * inch],
        cornerRadii=[6, 6, 6, 6],
    )
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), style.backColor or colors.white),
                ("LEFTPADDING", (0, 0), (-1, -1), 11),
                ("RIGHTPADDING", (0, 0), (-1, -1), 11),
                ("TOPPADDING", (0, 0), (-1, -1), 9),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 9),
            ]
        )
    )
    return table


def make_cover(logo: Path, s: dict[str, ParagraphStyle]):
    story = [Spacer(1, 0.3 * inch)]
    if logo.exists():
        story.extend([Image(str(logo), width=1.4 * inch, height=1.4 * inch), Spacer(1, 0.2 * inch)])
    story.extend(
        [
            Paragraph(rich(AGREEMENT_TITLE, bold=True), s["cover_title"]),
            Paragraph(ENGLISH_TITLE, s["cover_en"]),
            Spacer(1, 0.18 * inch),
            HRFlowable(width="10%", thickness=2.5, color=RAYCAST_RED, spaceBefore=4, spaceAfter=14),
            Paragraph(rich(ENTITY), s["cover_meta"]),
            Spacer(1, 0.18 * inch),
            Paragraph(
                rich(f"协议版本 {VERSION}") + "<br/>" + rich("2026 年 8 月 2 日"),
                s["cover_meta"],
            ),
            Spacer(1, 0.42 * inch),
            callout(
                "本稿不得用于签署或上传为正式合同。发布前必须确认 California Dance Studio Surety Bond 的适用与备案状态，并由加州执业律师完成最终审阅。",
                s["warning"],
                "内部法律审阅稿 · NOT FOR SIGNATURE",
            ),
            Spacer(1, 0.22 * inch),
            Paragraph(rich("2 Jenner, Suite 180, Irvine, CA 92618"), s["cover_meta"]),
            Paragraph("masterdance.irvine@gmail.com", s["cover_meta"]),
            Paragraph("(619) 251-1945 · (619) 517-8093", s["cover_meta"]),
            Spacer(1, 0.18 * inch),
            Paragraph("Starton EDU Irvine, Inc. · Master Dance", s["cover_en"]),
            PageBreak(),
        ]
    )
    return story


def make_navigation(s: dict[str, ParagraphStyle]):
    rights = [
        ("01", "随时书面取消", "未提供服务按比例结算；退款在收到通知后 10 日内处理；不收取消费。"),
        ("02", "逐课看清价格", "每门课在接受前显示课次、时长、每次价、小时单价、总价和其他项目。"),
        ("03", "保留完整副本", "电子签署后可以下载、打印或转发；也可以选择纸质签署。"),
        ("04", "有限责任豁免", "只限法律允许的普通疏忽，不覆盖重大过失、故意、欺诈或违法。"),
        ("05", "无自动续费", "新学期必须重新确认课程和价格；不授权自动扣款。"),
    ]
    rows = []
    for number, title, detail in rights:
        number_para = Paragraph(
            f"<font name='{LATIN_BOLD_FONT}' color='#FF6363'>{number}</font>",
            s["body"],
        )
        detail_para = Paragraph(
            f"{rich(title, bold=True)}<br/><font color='#717178'>{rich(detail)}</font>",
            s["body"],
        )
        rows.append([number_para, detail_para])
    rights_table = Table(rows, colWidths=[0.42 * inch, 6.16 * inch], hAlign="LEFT")
    rights_table.setStyle(
        TableStyle(
            [
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LINEBELOW", (0, 0), (-1, -2), 0.45, LINE),
                ("TOPPADDING", (0, 0), (-1, -1), 7),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
                ("LEFTPADDING", (0, 0), (-1, -1), 0),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )

    section_titles = [
        "1-5  身份、协议体系、电子签署与帐号",
        "6-9  报名、注册费、价格与付款",
        "10-15  取消退款、停课、请假、补课与顺延",
        "16-21  健康、接送、秩序、风险与紧急医疗",
        "22-28  监控、隐私、媒体、通知与法律",
        "29  签署确认",
        "附件 A  每门课程报名确认单",
        "附件 B  电子记录与电子签名同意",
        "附件 C  独立可选媒体授权说明",
    ]
    story = [
        Paragraph(rich("先看这五项权利", bold=True), s["page_title"]),
        Paragraph("Key rights before you sign", s["small"]),
        Spacer(1, 0.05 * inch),
        rights_table,
        Spacer(1, 0.22 * inch),
        callout(
            "项目资料尚未证明 Dance Studio Surety Bond 已备案，也没有律师书面确认法定豁免。此项核实完成前，本文件只能用于内部审阅。",
            s["warning"],
            "发布阻断",
        ),
        Spacer(1, 0.15 * inch),
        Paragraph(rich("阅读导航", bold=True), s["section"]),
    ]
    story.extend(Paragraph(rich(item), s["toc"]) for item in section_titles)
    story.append(PageBreak())
    return story


def make_signature_table(fields: list[str], s: dict[str, ParagraphStyle]) -> Table:
    rows = []
    row_heights = []
    for item in fields:
        if "：" in item:
            label, value = item.split("：", 1)
        else:
            label, value = item, ""
        rows.append(
            [
                Paragraph(rich(label, bold=True), s["signature_field"]),
                Paragraph(rich(value), s["signature_field"]),
            ]
        )
        row_heights.append((0.86 if label == "签名" else 0.37) * inch)
    table = Table(
        rows,
        colWidths=[1.42 * inch, 5.2 * inch],
        rowHeights=row_heights,
        cornerRadii=[6, 6, 6, 6],
    )
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), SURFACE_2),
                ("BACKGROUND", (0, 0), (0, -1), SURFACE),
                ("LINEBELOW", (0, 0), (-1, -2), 0.45, LINE),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("LEFTPADDING", (0, 0), (-1, -1), 8),
                ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
            ]
        )
    )
    return table


def body_story(app_text: str, s: dict[str, ParagraphStyle]):
    lines = [line.strip() for line in app_text.splitlines()]
    start = next(i for i, line in enumerate(lines) if re.match(r"^1\.\s", line))
    lines = lines[start:]
    story = []
    in_signature = False
    signature_fields: list[str] = []

    field_prefixes = (
        "签署人姓名：",
        "帐号邮箱：",
        "适用学员：",
        "协议版本：",
        "签署日期、时间与时区：",
        "签名：",
        "学员姓名：",
        "购买方及家庭帐号：",
        "学期、课程、老师与教室：",
        "星期、开始时间与结束时间：",
        "首课日期、末课日期与实际课次：",
        "每次课时长：",
        "每次课程单价：",
        "折算小时单价：",
        "报名方式：",
        "课程费、注册费、折扣、用品或其他服务：",
        "信用卡价格或适用附加费：",
        "总价、已付、未付及付款安排：",
        "预计开课日期必须",
        "课程确认版本与接受时间：",
        "电子同意时间与设备记录：",
    )

    for line in lines:
        if not line:
            continue
        if re.match(r"^\d+\.\s", line):
            if line.startswith("29. "):
                story.append(PageBreak())
                in_signature = True
            story.append(Paragraph(section_markup(line), s["section"]))
            continue
        if line.startswith("附件 "):
            if signature_fields:
                story.extend([Spacer(1, 0.12 * inch), make_signature_table(signature_fields, s)])
                signature_fields = []
            in_signature = False
            if line.startswith("附件 C"):
                story.extend([Spacer(1, 0.22 * inch), Paragraph(appendix_markup(line), s["appendix"])])
            else:
                story.extend([PageBreak(), Paragraph(appendix_markup(line), s["appendix"])])
            continue
        if line.startswith("醒目责任豁免："):
            story.append(callout(line.removeprefix("醒目责任豁免：").strip(), s["waiver"], "醒目责任豁免"))
            continue
        if line.startswith("[ ]"):
            story.append(Paragraph(rich("□ " + line[3:].strip()), s["checkbox"]))
            continue
        if in_signature and line.startswith(field_prefixes):
            signature_fields.append(line)
            continue
        if line.startswith(field_prefixes):
            story.append(Paragraph(field_markup(line), s["field"]))
            continue
        if line.startswith("购买方确认："):
            story.append(
                callout(
                    line.removeprefix("购买方确认：").strip(),
                    s["confirmation"],
                    "购买方确认",
                )
            )
            continue
        story.append(Paragraph(rich(line), s["body"]))

    story.extend(
        [
            Spacer(1, 0.15 * inch),
            HRFlowable(width="100%", thickness=0.8, color=RAYCAST_RED, spaceBefore=8, spaceAfter=8),
            Paragraph(
                rich("本文件至此结束。签署版本应同时保存完整正文、版本号、正文校验值、签署时间、签署身份与签名图像。"),
                s["small"],
            ),
        ]
    )
    return story


def generate(
    source: Path,
    logo: Path,
    font_dir: Path,
    pdf_output: Path,
    app_output: Path,
):
    register_fonts(font_dir)
    markdown = source.read_text(encoding="utf-8")
    app_text = extract_app_text(markdown)
    if len(app_text) > 50_000:
        raise ValueError(f"App text exceeds 50,000 characters: {len(app_text)}")

    app_output.parent.mkdir(parents=True, exist_ok=True)
    app_output.write_text(app_text, encoding="utf-8", newline="\n")

    pdf_output.parent.mkdir(parents=True, exist_ok=True)
    s = styles()
    doc = SimpleDocTemplate(
        str(pdf_output),
        pagesize=letter,
        rightMargin=0.68 * inch,
        leftMargin=0.68 * inch,
        topMargin=0.72 * inch,
        bottomMargin=0.68 * inch,
        title=AGREEMENT_TITLE,
        author="Starton EDU Irvine, Inc. / Master Dance",
        subject="Internal legal review draft - not for signature",
        creator="Master Dance agreement generator",
    )
    story = []
    story.extend(make_cover(logo, s))
    story.extend(make_navigation(s))
    story.extend(body_story(app_text, s))
    doc.build(story, canvasmaker=AgreementCanvas)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--logo", required=True, type=Path)
    parser.add_argument(
        "--font-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "brand" / "fonts",
    )
    parser.add_argument("--pdf-output", required=True, type=Path)
    parser.add_argument("--app-output", required=True, type=Path)
    args = parser.parse_args()
    generate(args.source, args.logo, args.font_dir, args.pdf_output, args.app_output)


if __name__ == "__main__":
    main()

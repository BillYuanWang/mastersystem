# Embedded Agreement Fonts

The agreement PDF generator embeds these project-owned font files so the
document renders consistently without depending on fonts installed on the
machine that builds it.

| File | Family | Version | Official source | Use |
| --- | --- | --- | --- | --- |
| `Inter-Regular.ttf` | Inter | 4.1 | <https://github.com/rsms/inter/releases/tag/v4.1> | Latin body text and numerals |
| `Inter-SemiBold.ttf` | Inter | 4.1 | <https://github.com/rsms/inter/releases/tag/v4.1> | Latin headings and emphasis |
| `SourceHanSansCN-Regular.ttf` | Source Han Sans CN | 2.005R | <https://github.com/adobe-fonts/source-han-sans/releases/tag/2.005R> | Simplified Chinese body text |
| `SourceHanSansCN-Bold.ttf` | Source Han Sans CN | 2.005R | <https://github.com/adobe-fonts/source-han-sans/releases/tag/2.005R> | Simplified Chinese headings |

The files are static TrueType instances generated from the official variable
font releases at weights 400, 650, 400, and 700 respectively. Static instances
keep the PDF searchable and avoid machine-specific font substitution.

Both families are distributed under the SIL Open Font License 1.1. Keep
`LICENSE-INTER.txt` and `LICENSE-SOURCE-HAN-SANS.txt` with the font files when
redistributing them.

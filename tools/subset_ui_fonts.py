#!/usr/bin/env python3
"""Build renamed OFL CJK UI subsets. Requires fonttools and official Noto CJK source files.
Sources are not downloaded implicitly: supply --source-dir with upstream regular OTFs.
The subset covers bundled translations and native language names, not arbitrary CJK user text.
"""
import argparse,json,hashlib
from pathlib import Path
from fontTools import subset
from fontTools.ttLib import TTFont
p=argparse.ArgumentParser();p.add_argument('--source-dir',required=True,type=Path);a=p.parse_args()
r=Path(__file__).resolve().parents[1]
text=(r/'localization/catalog.json').read_text()+(r/'resources/achievements/registry.json').read_text()+(r/'scripts/ui/language_catalog.gd').read_text()
for path in (r/'tools').glob('private*.json'):text+=path.read_text()
text+='日本語한국어简体中文हिन्दीไทยالعربيةРусскийTiếng ViệtBahasa IndonesiaFrançaisItalianoDeutschTürkçeEnglish'
chars=set(ord(c) for c in text)|set(range(32,256))|set(range(0x3000,0x3100))|{0x2212,0x221e}
report={}
for lang in ['jp','kr','sc']:
 source=a.source_dir/f'NotoSansCJK{lang}-Regular.otf'
 font=TTFont(source)
 options=subset.Options();options.name_IDs=['*'];options.name_legacy=True;options.name_languages=['*'];options.layout_features=['*']
 sub=subset.Subsetter(options);sub.populate(unicodes=chars);sub.subset(font)
 for record in font['name'].names:
  if record.nameID in [1,3,4,6,16,17]:record.string=(f'BLASTORIAInterface{lang}' if record.nameID == 6 else f'BLASTORIA Interface {lang}').encode(record.getEncoding())
 font['CFF '].cff.fontNames=[f'BLASTORIAInterface{lang}']
 top=font['CFF '].cff.topDictIndex[0];top.FamilyName=f'BLASTORIA Interface {lang}';top.FullName=top.FamilyName
 target=r/f'assets/fonts/Interface-{lang}.otf';font.save(target)
 report[lang]={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'subset_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'bytes':target.stat().st_size}
(r/'docs/qa/font_sources.json').write_text(json.dumps(report,indent=2)+'\n');print(report)

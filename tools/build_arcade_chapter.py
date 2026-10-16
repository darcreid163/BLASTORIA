#!/usr/bin/env python3
"""Materialize seven authored layouts. Fixed geometry/placements; no RNG or runtime generation.
Existing stage_001..003 are deliberately never rewritten, preserving record fingerprints.
"""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
def span(x1,y1,x2,y2):
 return [(x,y) for y in range(y1,y2+1) for x in range(x1,x2+1)]
# title, walls, crates, enemies (x,y,role,step), powers (x,y,kind,hidden)
STAGES={
4:('Перекрёсток',span(5,3,8,5)+span(16,3,19,5)+span(5,11,8,13)+span(16,11,19,13),
 [(10,4),(14,4),(6,8),(12,8),(18,8),(10,12),(14,12),(3,6),(21,10)],
 [(12,5,'patrol',42),(20,8,'chaser',54),(12,13,'patrol',45)],
 [(3,1,'capacity',False),(10,4,'range',True),(6,8,'speed',True),(14,12,'range',True)]),
5:('Обходные пути',[p for p in span(6,2,6,13) if p[1] not in [4,11]]+[p for p in span(12,3,12,14) if p[1] not in [7,12]]+[p for p in span(18,1,18,12) if p[1] not in [5,10]],
 [(6,4),(6,11),(12,7),(18,5),(18,10),(3,8),(9,5),(15,11),(21,8)],
 [(10,3,'chaser',54),(15,9,'patrol',42),(21,13,'chaser',51)],
 [(3,1,'capacity',False),(3,8,'range',True),(9,5,'speed',True),(21,8,'wall_pass',True)]),
6:('Галерея фитилей',[p for p in span(4,4,20,4) if p[0] not in [8,16]]+[p for p in span(2,8,22,8) if p[0] not in [6,12,18]]+[p for p in span(4,12,20,12) if p[0] not in [8,16]],
 [(8,4),(16,4),(6,8),(18,8),(8,12),(16,12),(10,6),(14,10),(21,14)],
 [(20,2,'bomber',42),(8,6,'patrol',42),(16,10,'chaser',54),(21,13,'bomber',45)],
 [(3,1,'capacity',False),(8,4,'range',True),(10,6,'remote',True),(14,10,'speed',True)]),
7:('Кольцо Стража',[p for p in span(7,4,17,4)+span(7,12,17,12)+span(7,5,7,11)+span(17,5,17,11) if p not in [(12,4),(12,12),(7,8),(17,8)]],
 [(12,4),(12,12),(7,8),(17,8),(10,6),(14,10),(3,9),(21,6),(9,14)],
 [(12,7,'warden',60),(20,3,'patrol',42),(20,13,'chaser',51),(4,13,'patrol',42)],
 [(3,1,'capacity',False),(3,9,'range',True),(10,6,'flame_pass',True),(21,6,'speed',True)]),
8:('Два двора',[p for p in span(12,2,12,14) if p[1] not in [4,8,12]]+span(5,5,8,5)+span(5,5,5,8)+span(16,11,19,11)+span(19,8,19,11),
 [(12,4),(12,12),(3,4),(8,8),(7,11),(16,5),(21,8),(16,13),(9,14),(3,12)],
 [(9,3,'chaser',51),(8,12,'patrol',39),(16,3,'bomber',42),(21,13,'chaser',51),(16,9,'patrol',42)],
 [(3,1,'capacity',False),(3,4,'range',True),(8,8,'bomb_pass',True),(16,5,'remote',True),(16,13,'speed',True)]),
9:('Эстафета',[p for x in [5,11,17] for p in span(x,3,x,13) if p[1] not in [6,10]],
 [(5,6),(11,10),(17,6),(8,4),(8,12),(14,8),(20,4),(20,12),(3,9),(22,8),(14,14)],
 [(8,2,'patrol',39),(8,9,'chaser',48),(14,4,'bomber',42),(14,12,'patrol',39),(21,8,'warden',60),(21,14,'patrol',42)],
 [(3,1,'capacity',False),(3,9,'range',True),(8,4,'speed',True),(14,8,'capacity',True),(20,12,'invulnerability',True)]),
10:('Сердце лабиринта',span(7,4,9,6)+span(15,4,17,6)+span(7,10,9,12)+span(15,10,17,12)+[p for x in [3,21] for p in span(x,5,x,11) if p[1]!=8],
 [(6,8),(18,8),(12,5),(12,11),(5,3),(19,13),(4,12),(20,4),(10,14),(14,2),(6,13),(18,3)],
 [(11,4,'chaser',48),(13,12,'warden',60),(5,8,'bomber',42),(19,8,'bomber',42),(11,14,'patrol',39),(19,2,'chaser',51),(5,14,'patrol',39)],
 [(3,1,'capacity',False),(5,3,'range',True),(6,8,'speed',True),(12,11,'remote',True),(19,13,'capacity',True),(10,14,'wall_pass',True)])}
for number,(title,walls,crates,enemies,powers) in STAGES.items():
 rows=[list('#'*25) if y in [0,16] else list('#'+'.'*23+'#') for y in range(17)]
 for x,y in walls:rows[y][x]='#'
 for x,y in crates:
  assert rows[y][x]=='.',(number,'crate',x,y)
  rows[y][x]='C'
 for x,y,_,_ in enemies:assert rows[y][x]=='.',(number,'enemy',x,y)
 for x,y,_,hidden in powers:assert rows[y][x]==('C' if hidden else '.'),(number,'power',x,y)
 data={'format':2,'id':f'arcade_{number:03d}','revision':1,'title':title,'author':'BLASTORIA','description':'Авторская карта первой главы','created':'2026-10-16','modified':'2026-10-16','mode':'solo','theme':'green_maze','width':25,'height':17,'seed':23000+number,'generator_version':0,'rows':[''.join(row) for row in rows],'spawns':[[1,1]],'enemies':[{'cell':[x,y],'kind':kind,'step':step,'required':True} for x,y,kind,step in enemies],'powerups':[{'cell':[x,y],'kind':kind,'hidden':hidden} for x,y,kind,hidden in powers],'rules':{'capacity':1,'range':2,'fuse_ticks':150,'remote':False,'time_limit':0,'goal':'eliminate'},'generation':{}}
 (ROOT/f'resources/arcade/stage_{number:03d}.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
registry=ROOT/'resources/arcade/registry.json';data=json.loads(registry.read_text());data['themes'][0]['status']='authored_chapter'
for number in STAGES:data['levels'][number-1].update(status='playable',path=f'res://resources/arcade/stage_{number:03d}.json')
registry.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
print('Seven fixed authored layouts written; stages 1-3 preserved.')

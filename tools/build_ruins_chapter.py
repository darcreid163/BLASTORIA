#!/usr/bin/env python3
"""Ten fixed authored layouts: water (~) blocks movement and fire, bridges are floor.
Never rewrites stage_001..010; no runtime procedural generation or random placement.
"""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
def span(x1,y1,x2,y2):return [(x,y) for y in range(y1,y2+1) for x in range(x1,x2+1)]
def vertical(x,gates):return [p for p in span(x,1,x+1,15) if p[1] not in gates]
def horizontal(y,gates):return [p for p in span(1,y,23,y+1) if p[0] not in gates]
# title, water, stone, crates, enemies (x,y,role,step), hidden powers (x,y,kind)
STAGES={
11:('Первый мост',vertical(8,[4,12]),span(15,5,17,7)+span(15,11,17,12),[(6,4),(10,12),(12,3),(20,8),(5,11),(19,13)],[(12,5,'patrol',39),(20,3,'chaser',51),(19,12,'bomber',42),(4,13,'patrol',42)],[(6,4,'range'),(5,11,'speed'),(19,13,'capacity')]),
12:('Разделённый двор',horizontal(7,[5,12,20]),span(9,3,10,4)+span(15,11,16,12),[(5,7),(20,8),(7,4),(16,3),(6,12),(19,12),(12,11)],[(6,5,'chaser',51),(18,4,'patrol',39),(5,12,'bomber',42),(20,12,'chaser',51),(12,14,'patrol',39)],[(7,4,'range'),(6,12,'remote'),(19,12,'speed')]),
13:('Три переправы',vertical(7,[3,11])+vertical(16,[5,13]),span(11,7,13,8),[(7,11),(16,5),(12,4),(12,12),(20,8),(4,7),(21,14)],[(11,3,'patrol',39),(13,11,'bomber',42),(20,4,'chaser',48),(20,13,'patrol',39),(4,12,'chaser',51)],[(4,7,'range'),(12,12,'bomb_pass'),(20,8,'speed')]),
14:('Каменные острова',span(6,4,9,6)+span(16,4,19,6)+span(6,10,9,12)+span(16,10,19,12),span(11,6,13,6)+span(11,10,13,10),[(5,8),(19,8),(12,4),(12,12),(4,13),(21,3),(10,14),(14,2)],[(12,3,'warden',60),(4,8,'bomber',42),(20,8,'bomber',42),(12,13,'chaser',48),(21,13,'patrol',39)],[(5,8,'range'),(12,12,'remote'),(4,13,'flame_pass'),(21,3,'speed')]),
15:('Петля течения',[p for p in span(6,4,18,4)+span(6,12,18,12)+span(6,5,6,11)+span(18,5,18,11) if p not in [(10,4),(14,12),(6,8),(18,8)]],span(10,7,14,9),[(6,8),(18,8),(10,4),(14,12),(3,6),(21,10),(9,14),(16,2)],[(12,5,'chaser',48),(8,10,'patrol',39),(16,6,'warden',60),(20,13,'bomber',42),(4,13,'chaser',48),(20,3,'patrol',39)],[(3,6,'range'),(14,12,'capacity'),(21,10,'remote'),(9,14,'speed')]),
16:('Смотровые галереи',horizontal(5,[4,11,20])+horizontal(11,[6,15,22]),span(14,2,14,3)+span(9,8,10,9),[(11,5),(6,11),(19,8),(5,3),(16,8),(12,14),(21,14),(3,9)],[(8,3,'patrol',36),(18,3,'bomber',39),(5,8,'chaser',48),(20,8,'warden',57),(10,13,'bomber',42),(21,13,'chaser',48)],[(5,3,'range'),(3,9,'speed'),(16,8,'remote'),(12,14,'capacity')]),
17:('Ворота Стража',vertical(6,[4,12])+vertical(18,[4,12]),span(10,5,14,5)+span(10,11,14,11),[(6,12),(18,4),(10,8),(14,8),(9,3),(15,13),(3,10),(21,7)],[(11,3,'warden',57),(13,13,'warden',57),(9,8,'bomber',39),(15,8,'patrol',36),(21,4,'chaser',45),(21,13,'chaser',48)],[(3,10,'range'),(10,8,'flame_pass'),(14,8,'remote'),(15,13,'speed')]),
18:('Дальний причал',vertical(10,[3,13])+[p for p in horizontal(8,[5,18]) if p[0] not in [10,11]],span(3,4,5,5)+span(16,11,19,12),[(10,3),(5,8),(18,9),(8,12),(14,4),(21,6),(6,14),(22,14),(14,13)],[(7,3,'chaser',48),(18,3,'bomber',39),(7,12,'patrol',36),(14,12,'warden',57),(21,13,'bomber',42),(19,6,'chaser',45),(3,13,'patrol',39)],[(8,12,'range'),(14,4,'remote'),(21,6,'bomb_pass'),(6,14,'speed'),(22,14,'invulnerability')]),
19:('Перекрёстные каналы',vertical(7,[4,12])+vertical(16,[4,12])+[p for p in horizontal(8,[4,12,21]) if p[0] not in [7,8,16,17]],[],[(7,4),(16,12),(4,8),(21,9),(12,5),(12,11),(4,13),(20,3),(12,14),(22,13)],[(11,3,'bomber',39),(13,6,'chaser',45),(4,12,'warden',57),(11,13,'patrol',36),(20,5,'bomber',39),(21,12,'chaser',45),(3,6,'patrol',39)],[(4,13,'range'),(12,5,'speed'),(12,11,'remote'),(20,3,'capacity'),(22,13,'flame_pass')]),
20:('Сердце руин',span(5,4,8,6)+span(16,4,19,6)+span(5,10,8,12)+span(16,10,19,12)+[p for p in span(11,4,13,12) if p[1] not in [6,10]],[],[(4,8),(20,8),(10,6),(14,10),(3,4),(21,12),(10,14),(14,2),(9,10),(15,6),(3,13),(21,3)],[(10,3,'chaser',45),(14,13,'warden',54),(3,8,'bomber',39),(21,8,'bomber',39),(10,13,'patrol',36),(20,2,'chaser',45),(4,14,'patrol',36),(14,7,'warden',57)],[(3,4,'range'),(4,8,'speed'),(14,10,'remote'),(21,12,'capacity'),(10,14,'wall_pass'),(21,3,'invulnerability')])}
for number,(title,water,walls,crates,enemies,powers) in STAGES.items():
 rows=[list('#'*25) if y in [0,16] else list('#'+'.'*23+'#') for y in range(17)]
 for x,y in set(water):rows[y][x]='~'
 for x,y in set(walls):
  assert rows[y][x]=='.',(number,'wall',x,y)
  rows[y][x]='#'
 for x,y in crates:
  assert rows[y][x]=='.',(number,'crate',x,y)
  rows[y][x]='C'
 for x,y,_,_ in enemies:assert rows[y][x]=='.',(number,'enemy',x,y)
 for x,y,_ in powers:assert rows[y][x]=='C',(number,'power',x,y)
 assert all(rows[y][x]=='.' for x,y in [(1,1),(2,1),(1,2),(3,1)])
 data={'format':2,'id':f'arcade_{number:03d}','revision':1,'title':title,'author':'BLASTORIA','description':'Авторская карта второй главы','created':'2026-10-16','modified':'2026-10-16','mode':'solo','theme':'flooded_ruins','width':25,'height':17,'seed':24000+number,'generator_version':0,'rows':[''.join(row) for row in rows],'spawns':[[1,1]],'enemies':[{'cell':[x,y],'kind':kind,'step':step,'required':True} for x,y,kind,step in enemies],'powerups':[{'cell':[3,1],'kind':'capacity','hidden':False}]+[{'cell':[x,y],'kind':kind,'hidden':True} for x,y,kind in powers],'rules':{'capacity':1,'range':2,'fuse_ticks':150,'remote':False,'time_limit':0,'goal':'eliminate'},'generation':{}}
 (ROOT/f'resources/arcade/stage_{number:03d}.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
p=ROOT/'resources/arcade/registry.json';registry=json.loads(p.read_text());registry['themes'][1]['status']='authored_chapter'
for n in STAGES:registry['levels'][n-1].update(status='playable',path=f'res://resources/arcade/stage_{n:03d}.json')
p.write_text(json.dumps(registry,ensure_ascii=False,indent=2)+'\n')
print('Ten fixed ruins layouts written. Existing stage files untouched.')

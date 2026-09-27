from analyze_game_data import *
from datetime import datetime
import math

a=json.loads((OUT/'analysis.json').read_text(encoding='utf-8'))
d=a['daily']
e={}
e['file_count']=len(datasets)
e['null_cells']={n:sum(v=='null' for r in rows for v in r.values()) for n,rows in datasets.items() if any(v=='null' for r in rows for v in r.values())}
e['source_files']={n:{'rows':len(rows),'sha256':hashlib.sha256((DATA/n).read_bytes()).hexdigest()} for n,rows in datasets.items()}

# Reconcile daily components; retain any realtime/restated differences explicitly.
source_name, source_rows=pick('Robux sources-')
source_groups={g:series('Robux sources-',g) for g in {r['Revenue Source'] for r in source_rows}}
assert all(abs(sum(v[date] for g,v in source_groups.items() if g!='Total')-total)<0.01 for date,total in source_groups['Total'].items())
e['revenue_source_reconciliation']='PASS: components = total on all 28 days'
e['realtime_differences']={}
for filename,rows in datasets.items():
    if filename.startswith('Universe-10447471170- Robux Spent'):
        expected='Passes' if '(1).csv' in filename else 'Developer Products'
        raw={r['Date'][:10]:float(r['Robux Spent (Realtime)']) for r in rows if r['']=='Total'}
        diffs={date:val-source_groups[expected][date] for date,val in raw.items() if date in source_groups[expected] and val!=source_groups[expected][date]}
        e['realtime_differences'][expected]=diffs

# Exported conversion has small processing/population differences; label our ratios.
e['max_daily_payer_conversion_difference_pp']=max(abs(d['payers'][day]/d['dau'][day]-d['payer_conversion'][day])*100 for day in d['dau'])
e['max_daily_arpdau_difference']=max(abs(d['revenue'][day]/d['dau'][day]-d['arpdau'][day]) for day in d['dau'])
e['pricing_break_even']={f'{old}->{new}':old/new-1 for old,new in [(50,29),(20,9),(29,19),(119,99),(219,179)]}
e['normalized_week_changes']={key: ((sum(v for day,v in source_groups[key].items() if '2026-09-12'<=day<='2026-09-18')/a['weeks'][3]['dau_sum'])/(sum(v for day,v in source_groups[key].items() if '2026-09-05'<=day<='2026-09-11')/a['weeks'][2]['dau_sum'])-1) for key in ['Developer Products','Passes']}

def req(level,first=False):
    if level<=30: normal=37*1.166950047752463**(level-1)
    else: normal=37*1.166950047752463**29*1.1477**(min(level,100)-30)*1.166950047752463**max(0,level-100)
    factor=(.5+.2*(level-1)/16 if level<=17 else .8 if level==18 else .9 if level==19 else 1) if first else 1
    return normal*factor
def level_from_speed(speed,first=False):
    remaining=speed-1+(.77*req(1,True) if first else 0)
    level=1
    while remaining>=req(level,first):remaining-=req(level,first);level+=1
    return level
e['level_curve']={str(s):{'first_run_level':level_from_speed(s,True),'normal_level':level_from_speed(s)} for s in [100,100000,1000000]}
e['world2_gain_ratio_same_mobius_skin']=(3*40)/(10*110)
e['daily_vs_starter_speed_ratio']=1000000/100000
e['last_week_treadmills_revenue']=sum(float(r['Robux Spent (Realtime)']) for n,rows in datasets.items() if n.startswith('Universe-10447471170- Robux Spent') and '(1).csv' in n for r in rows if r[''] in ['Hacker Treadmill','Valentine Treadmill','Admin Treadmill'] and '2026-09-12'<=r['Date'][:10]<='2026-09-18')
e['old_speed_ladder_revenue_drop']=sum(float(r['Robux Spent (Realtime)'])*(1 if '2026-09-05'<=r['Date'][:10]<='2026-09-11' else -1 if '2026-09-12'<=r['Date'][:10]<='2026-09-18' else 0) for n,rows in datasets.items() if n.startswith('Universe-10447471170- Robux Spent') and '(1).csv' not in n for r in rows if r[''] in ['x2 Speed','x4 Speed','x10 Speed'])
e['recovery_scenario_weekly']=a['weeks'][3]['dau_sum']*(a['weeks'][2]['arpdau_weighted']-a['weeks'][3]['arpdau_weighted'])

(OUT/'evidence.json').write_text(json.dumps(e,indent=2,ensure_ascii=False),encoding='utf-8')
print(json.dumps({k:v for k,v in e.items() if k not in ['source_files','realtime_differences']},indent=2,ensure_ascii=False))

chart_data={k:[[day,round(v,6)] for day,v in d[k].items() if day>='2026-08-22'] for k in ['dau','revenue','payer_conversion','d1']}
(OUT/'chart_data.json').write_text(json.dumps(chart_data),encoding='utf-8')

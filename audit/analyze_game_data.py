from pathlib import Path
import csv, json, hashlib, statistics, sys
from collections import defaultdict

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'DataAnalysis'
OUT = ROOT / 'output' / 'GameAnalysis_20260919'
OUT.mkdir(parents=True, exist_ok=True)

def read_csv(path):
    with path.open(encoding='utf-8-sig', newline='') as f:
        records = [r for r in csv.reader(f) if r]
    header_at = next(i for i, r in enumerate(records) if len(r) >= 3)
    return [dict(zip(records[header_at], r)) for r in records[header_at+1:]]

datasets = {}
for path in sorted(DATA.glob('*.csv')):
    rows = read_csv(path)
    datasets[path.name] = rows

def pick(prefix):
    matches = [(n,r) for n,r in datasets.items() if n.startswith(prefix)]
    assert len(matches) == 1, (prefix, len(matches))
    return matches[0]

def series(prefix, group='Total'):
    name, rows = pick(prefix)
    headers = list(rows[0])
    return {r['Date'][:10]: float(r[headers[-1]]) for r in rows if r[headers[0]] == group and r[headers[-1]] not in ('null','')}

def summarize():
    metrics = {
        'dau':'Daily active users-', 'revenue':'Daily Robux spent-',
        'payers':'Paying users-', 'sessions':'Sessions-', 'hours':'Total playtime-',
        'session_minutes':'Average session time-', 'play_minutes':'Average playtime-',
        'arpdau':'Average Robux spent per daily user-', 'arppu':'Average Robux spent per paying user-',
        'payer_conversion':'Payer conversion rate-', 'd1':'Day 1 retention-',
        'd7':'Day 7 retention-', 'd30':'Day 30 retention-', 'mau':'Monthly active users by day-',
        'stickiness':'Stickiness (', 'not_interested':'Not interested rate',
    }
    daily = {k: series(v) for k,v in metrics.items()}
    weeks = []
    for start,end in [('2026-08-22','2026-08-28'),('2026-08-29','2026-09-04'),('2026-09-05','2026-09-11'),('2026-09-12','2026-09-18')]:
        block = {'start':start,'end':end}
        for k,values in daily.items():
            selected = [v for d,v in values.items() if start <= d <= end]
            if selected: block[k+'_mean']=statistics.mean(selected); block[k+'_n']=len(selected)
        sums = {k:sum(v for d,v in daily[k].items() if start<=d<=end) for k in ['dau','revenue','payers','sessions','hours']}
        block.update({k+'_sum':v for k,v in sums.items()})
        block['arpdau_weighted']=sums['revenue']/sums['dau']
        block['conversion_weighted']=sums['payers']/sums['dau']
        block['arppu_weighted']=sums['revenue']/sums['payers']
        block['session_minutes_weighted']=sums['hours']*60/sums['sessions']
        block['play_minutes_weighted']=sums['hours']*60/sums['dau']
        weeks.append(block)
    groups = {}
    for name, rows in datasets.items():
        headers=list(rows[0]); value_key=headers[-1]; group_key=headers[0]
        buckets=defaultdict(list)
        for r in rows:
            try: value=float(r[value_key])
            except (ValueError,TypeError): continue
            buckets[r[group_key]].append((r.get('Date', r.get('Seconds Since Start','')), value))
        groups[name]={k:{'n':len(v),'sum':sum(x[1] for x in v),'mean':statistics.mean(x[1] for x in v),'min':min(x[1] for x in v),'max':max(x[1] for x in v),'last':v[-1], 'nonzero_dates':[x[0] for x in v if x[1]!=0]} for k,v in buckets.items()}
    result={'weeks':weeks,'daily':daily,'groups':groups}
    (OUT/'analysis.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print('WEEKS',json.dumps(weeks,ensure_ascii=False,indent=2))
    print('DAILY')
    for d in daily['dau']:
        print(d, ' '.join(f'{k}={daily[k].get(d,0):.4f}' for k in ['dau','revenue','payers','session_minutes','d1','d7','arpdau','mau']))
    for name,g in groups.items():
        if any(x in name for x in ['Funnel','Robux Spent (Realtime)','Client frame','Client memory usage-','Client crash','Monthly active users,','Unique users with plays, Source','30D revenue','Robux sources','User ratings']):
            compact={k:{a:b for a,b in v.items() if a!='nonzero_dates'} for k,v in g.items()}
            print(name,json.dumps(compact,ensure_ascii=False))
    print('FIRST SESSION')
    for r in pick('New user first session')[1]:
            if int(r['Seconds Since Start']) in [30,60,120,180,300,600,900,1200,1800]: print(r)

def details():
    a=json.loads((OUT/'analysis.json').read_text(encoding='utf-8'))
    daily=a['daily']
    before,after=a['weeks'][2:]
    print('WEEK CHANGES', {k:round((after[k]/before[k]-1)*100,2) for k in ['dau_mean','revenue_sum','arpdau_weighted','conversion_weighted','arppu_weighted','session_minutes_weighted','play_minutes_weighted']})
    print('MATCHED D1',[(lo,hi,statistics.mean(v for d,v in daily['d1'].items() if lo<=d<=hi)) for lo,hi in [('2026-09-06','2026-09-11'),('2026-09-12','2026-09-17')]])
    for prefix in ['Universe-10447471170- Robux Spent','Robux sources','Universe-10447471170- Unique users','Monthly active users, Country','Monthly active users, Language','Monthly active users, Age','Peak concurrent','Session time by place','Unexpected out']:
        for name, rows in datasets.items():
            if not name.startswith(prefix): continue
            headers=list(rows[0]); g=defaultdict(dict)
            for r in rows:
                try:v=float(r[headers[-1]])
                except ValueError:continue
                g[r[headers[0]]][r.get('Date','snapshot')[:10]]=v
            print('\nFILE',name)
            if 'Monthly active users,' in name:
                total=sum(next(iter(v.values())) for v in g.values())
                print('total',total,'top',[(k,round(next(iter(v.values()))/total*100,2)) for k,v in list(g.items())[:12]])
            elif 'Robux' in name or 'Revenue' in name or 'Unique users' in name:
                for group, vals in g.items():
                    b=sum(v for d,v in vals.items() if '2026-09-05'<=d<='2026-09-11')
                    c=sum(v for d,v in vals.items() if '2026-09-12'<=d<='2026-09-18')
                    print(group,'week_before',b,'week_after',c,'change_pct',round((c/b-1)*100,2) if b else None,
                          'Sep11-19',[(d,v) for d,v in vals.items() if d>='2026-09-11'])
            else:
                for group in g:
                    vals=[float(r[headers[-1]]) for r in rows if r[headers[0]]==group and r[headers[-1]]!='null']
                    print(group, 'mean',round(statistics.mean(vals),4),'sum',round(sum(vals),4))
    print('DAU exports compare', [(d,daily['dau'][d],v) for d,v in series('Universe-10447471170- Daily','Total (current)').items() if d>='2026-09-12'])
    print('Funnel nonzero dates',sorted(set(d for n,g in a['groups'].items() if n.startswith('Funnel') for k,v in g.items() for d in v['nonzero_dates'])))

if __name__ == '__main__' and '--details' in sys.argv:
    details()
elif __name__ == '__main__' and '--summary' in sys.argv:
    summarize()
elif __name__ == '__main__':
    inventory = []
    for name, rows in datasets.items():
        columns = list(rows[0]) if rows else []
        info = {'file': name, 'rows': len(rows), 'columns': columns,
                'first': rows[:2], 'last': rows[-1:]}
        inventory.append(info)
        print(json.dumps(info, ensure_ascii=False))
    (OUT / 'inventory.json').write_text(json.dumps(inventory, ensure_ascii=False, indent=2), encoding='utf-8')

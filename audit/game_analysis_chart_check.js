
(() => {
  const root=document.getElementById('speedster-analysis-trends');
  const data=JSON.parse(document.getElementById('speedster-chart-data').textContent);
  const definitions=[
    ['dau','Usuarios activos diarios','Miles de usuarios',.001],
    ['revenue','Ingresos diarios reportados','Miles de Robux',.001],
    ['payer_conversion','Jugadores que pagan','% de usuarios diarios',100],
    ['d1','Retención al día siguiente','% de cada cohorte',100]
  ];
  const parse=d3.utcParse('%Y-%m-%d'), format=d3.utcFormat('%d/%m');
  const number=new Intl.NumberFormat('es-MX',{maximumFractionDigits:2});
  definitions.forEach(([key,title,unit,factor])=>{
    const panel=document.createElement('div'); panel.className='speedster-plot';
    const heading=document.createElement('div');heading.textContent=title;panel.appendChild(heading);
    const svg=d3.create('svg').attr('class','speedster-chart').attr('role','img').attr('aria-label',title+'. '+unit+'. Descenso desde mediados de septiembre.');
    panel.appendChild(svg.node());root.querySelector('.speedster-plots').appendChild(panel);
    const values=data[key].map(([date,value])=>({date:parse(date),value:value*factor}));
    function draw(){
      const width=panel.getBoundingClientRect().width,height=250;
      if(width<100)return;
      const m={left:66,right:18,top:20,bottom:54};
      svg.attr('viewBox',`0 0 ${width} ${height}`).attr('height',height);svg.selectAll('*').remove();
      svg.append('title').text(title);
      const ext=d3.extent(values,d=>d.value), yMax=Math.max(ext[1]*1.12,.01);
      const x=d3.scaleUtc().domain(d3.extent(data.dau,d=>parse(d[0]))).range([m.left+3,width-m.right-3]);
      const y=d3.scaleLinear().domain([0,yMax]).nice(4).range([height-m.bottom-3,m.top+3]);
      svg.append('rect').attr('data-chart-frame','').attr('x',m.left).attr('y',m.top).attr('width',width-m.left-m.right).attr('height',height-m.top-m.bottom).attr('fill','none').attr('stroke','var(--border)');
      svg.append('rect').attr('x',x(parse('2026-09-13'))).attr('y',m.top+1).attr('width',x(parse('2026-09-18'))-x(parse('2026-09-13'))).attr('height',height-m.top-m.bottom-2).attr('fill','var(--viz-series-2)').attr('opacity',.09);
      svg.append('g').attr('transform',`translate(0,${height-m.bottom})`).call(d3.axisBottom(x).ticks(width<360?3:4).tickFormat(format)).attr('class','text-small');
      svg.append('g').attr('transform',`translate(${m.left},0)`).call(d3.axisLeft(y).ticks(4).tickFormat(v=>number.format(v))).attr('class','text-small');
      svg.append('text').attr('class','axis-title text-small').attr('data-axis','x').attr('text-anchor','middle').attr('x',(m.left+width-m.right)/2).attr('y',height-9).text(key==='d1'?'Fecha de cohorte':'Fecha');
      svg.append('text').attr('class','axis-title text-small').attr('data-axis','y').attr('x',m.left).attr('y',12).text(unit);
      svg.append('path').datum(values).attr('fill','none').attr('stroke','var(--viz-series-1)').attr('stroke-width',2).attr('d',d3.line().x(d=>x(d.date)).y(d=>y(d.value)));
      svg.selectAll('circle').data(values).join('circle').attr('cx',d=>x(d.date)).attr('cy',d=>y(d.value)).attr('r',2.6).attr('fill','var(--viz-series-1)');
      svg.selectAll('rect.hit').data(values).join('rect').attr('class','hit').attr('data-chart-hit','').attr('x',d=>Math.max(m.left,x(d.date)-16)).attr('y',m.top).attr('width',d=>Math.min(32,width-m.right-Math.max(m.left,x(d.date)-16))).attr('height',height-m.top-m.bottom).attr('fill','transparent').attr('data-tooltip',d=>`${format(d.date)}: ${number.format(d.value)} ${unit}`);
      const ticks=svg.selectAll('.tick text').nodes();
      for(let i=1;i<ticks.length;i++){
        const prev=ticks[i-1].getBoundingClientRect(),curr=ticks[i].getBoundingClientRect();
        if(Math.abs(prev.top-curr.top)<4 && curr.left<prev.right+4) ticks[i].style.visibility='hidden';
      }
    }
    new ResizeObserver(draw).observe(panel);draw();
  });
})();

export const packs={en:{name:'English',pdf:'pdf',images:'images|photos|pictures',month:'last month',week:'last week|last 7 days',large:'larger than|over',modified:'modified|changed',created:'created'},de:{name:'Deutsch',pdf:'pdf',images:'bilder|fotos',month:'letzten monat',week:'letzte woche',large:'größer als|über',modified:'geändert',created:'erstellt'},fr:{name:'Français',pdf:'pdf',images:'images|photos',month:'mois dernier',week:'semaine dernière',large:'plus de',modified:'modifiés|modifié',created:'créés|créé'},es:{name:'Español',pdf:'pdf',images:'imágenes|fotos',month:'mes pasado',week:'semana pasada',large:'más de',modified:'modificados|modificado',created:'creados|creado'},tr:{name:'Türkçe',pdf:'pdf',images:'resimler|fotoğraflar|görseller',month:'geçen ay',week:'geçen hafta|son 7 gün',large:'büyük',modified:'değiştirilen|değiştirilmiş',created:'oluşturulan'}};
export function parse(text,language='en',now=new Date(),custom={}){
 const p=custom[language]||packs[language]||packs.en,t=text.toLocaleLowerCase(language),rules=[];const has=k=>new RegExp(p[k],'iu').test(t);let recognized=false;
 if(has('pdf')){rules.push({field:'extension',op:'equals',value:'pdf'});recognized=true;}
 else if(has('images')){rules.push({field:'extension',op:'regex',value:'^(jpg|jpeg|png|gif|webp|heic|tiff|svg)$'});recognized=true;}
 const amount=t.match(/(\d+(?:[.,]\d+)?)\s*(kb|mb|gb|ko|mo|go)/i);
 if(amount){const n=Number(amount[1].replace(',','.'))*({k:1000,m:1e6,g:1e9}[amount[2][0]]);rules.push({field:'size',op:'greater',value:String(n)});recognized=true;}
 const field=has('created')?'created':'modified';let from,to;
 if(has('month')){from=new Date(now.getFullYear(),now.getMonth()-1,1);to=new Date(now.getFullYear(),now.getMonth(),1);}
 else if(has('week')){from=new Date(now);from.setDate(from.getDate()-7);to=now;}
 if(from){rules.push({field,op:'after',value:String(from.getTime()-1)},{field,op:'before',value:String(to.getTime())});recognized=true;}
 const quoted=text.match(/"([^"]+)"/);if(quoted)rules.push({field:'name',op:'contains',value:quoted[1]});
 if(!recognized&&!quoted&&text.trim())rules.push({field:'name',op:'contains',value:text.trim()});
 return {rules,notice:recognized?'Review the interpreted rules before searching. Other wording may not be understood in 0.1.':'Searching literal filename text.'};
}

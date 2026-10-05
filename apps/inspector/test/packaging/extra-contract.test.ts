import {it,expect} from 'vitest';
import {independentExtraResult} from '../../scripts/verification.js';
it('independent extra validator keeps OCR in ETC and rejects extra fields, official technique mixing, duplicate owners and BOM',()=>{
 const value={meta:{topic:'TOPIC',entry_url:'http://example.test/',started_at:'2026-10-04T01:00:00Z',finished_at:'2026-10-04T01:00:01Z',elapsed_sec:1},findings:[{id:'one',url:'http://example.test/',is_violation:true,location:'#banner',evidence_text:'OCR 원문',technique:'ETC',extra_finding:'IMAGE_AD_OCR'}]};
 const encode=(v:unknown)=>Buffer.from(JSON.stringify(v));expect(independentExtraResult(encode(value)).findings[0].evidence_text).toBe('OCR 원문');
 for(const patch of [{technique:'TRANSPARENT'},{extra_finding:'other'},{sourceType:'image_ocr'}])expect(()=>independentExtraResult(encode({...value,findings:[{...value.findings[0],...patch}]}))).toThrow();
 expect(()=>independentExtraResult(encode({...value,findings:[value.findings[0],{...value.findings[0],id:'two'}]}))).toThrow();
 expect(()=>independentExtraResult(Buffer.concat([Buffer.from([239,187,191]),encode(value)]))).toThrow();
});

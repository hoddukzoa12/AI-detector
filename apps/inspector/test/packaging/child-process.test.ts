import {spawn,type ChildProcess} from 'node:child_process';
import {once} from 'node:events';
import {it,expect} from 'vitest';
import {stopDeploymentChild} from '../../scripts/child-process.js';
async function ready(){const child=spawn(process.execPath,['-e','process.stdout.write("READY");setInterval(()=>{},1000)'],{stdio:['ignore','pipe','ignore']});await once(child.stdout!,'data');return child;}
async function bounded(child:ChildProcess){let timer:NodeJS.Timeout|undefined;try{await Promise.race([stopDeploymentChild(child,30),new Promise<never>((_,reject)=>{timer=setTimeout(()=>reject(new Error('Teardown never completed after signal exit')),300);})]);}finally{if(timer)clearTimeout(timer);}}
it('finishes when its real owned Node child terminates by SIGTERM with null exitCode',async()=>{const child=await ready();try{await bounded(child);expect(child.exitCode).toBeNull();expect(child.signalCode).toBe('SIGTERM');}finally{if(child.exitCode===null&&child.signalCode===null)child.kill('SIGKILL');}});
it('finishes immediately for an already signal-terminated owned child instead of awaiting a second exit',async()=>{const child=await ready();const exit=once(child,'exit');child.kill('SIGTERM');await exit;expect(child.exitCode).toBeNull();expect(child.signalCode).toBe('SIGTERM');await bounded(child);});
it('finishes for a real child with a numeric exit code',async()=>{const child=spawn(process.execPath,['-e','process.exit(0)']);await once(child,'exit');await bounded(child);expect(child.exitCode).toBe(0);});

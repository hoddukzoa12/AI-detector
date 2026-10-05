/** Bounded teardown of a process owned by a deployment test. A signal exit has a null exitCode. */
import type {ChildProcess} from 'node:child_process';
export async function stopDeploymentChild(child:ChildProcess,graceMs=5000):Promise<void>{
 if(!Number.isSafeInteger(graceMs)||graceMs<1)throw new Error('Invalid child teardown deadline');
 let exited=child.exitCode!==null||child.signalCode!==null||child.pid===undefined;
 const terminal=()=>exited||child.exitCode!==null||child.signalCode!==null;
 const signalAndWait=(signal:NodeJS.Signals)=>new Promise<void>(resolve=>{
  if(terminal()){resolve();return;}
  const finish=()=>{clearTimeout(timer);child.removeListener('exit',onExit);child.removeListener('close',onExit);resolve();};
  const onExit=()=>{exited=true;finish();};
  child.once('exit',onExit);child.once('close',onExit);
  const timer=setTimeout(finish,graceMs);
  if(terminal()){finish();return;}
  child.kill(signal);
 });
 if(terminal())return;
 await signalAndWait('SIGTERM');
 if(terminal())return;
 await signalAndWait('SIGKILL');
 if(!terminal())throw new Error('Owned child did not terminate within teardown deadline');
}

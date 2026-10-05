export type EvidenceRecord = {
  id: string;
  sequence: number;
  targetId: string;
  matchedTerm: string;
  url: string;
  pageTitle: string;
  matchedText: string;
  htmlExcerpt: string;
  capturedAt: string;
  pngSha256: string;
  htmlSha256: string;
  pdfFilename: string;
  downloadId: number | null;
};

const DB_NAME = "infocutter-evidence";
const DB_VERSION = 1;
const STORE = "records";

function openDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(STORE)) {
        const store = db.createObjectStore(STORE, { keyPath: "id" });
        store.createIndex("byDedup", ["url", "htmlSha256"], { unique: false });
        store.createIndex("bySequence", "sequence", { unique: false });
      }
    };
    request.onsuccess = () => { resolve(request.result); };
    request.onerror = () => { reject(request.error ?? new Error("IndexedDB open failed")); };
  });
}

export async function appendEvidence(record: EvidenceRecord): Promise<void> {
  const db = await openDb();
  await new Promise<void>((resolve, reject) => {
    const tx = db.transaction(STORE, "readwrite");
    tx.objectStore(STORE).add(record);
    tx.oncomplete = () => { resolve(); };
    tx.onerror = () => { reject(tx.error ?? new Error("IndexedDB append failed")); };
  });
  db.close();
}

export async function listEvidence(): Promise<EvidenceRecord[]> {
  const db = await openDb();
  const records = await new Promise<EvidenceRecord[]>((resolve, reject) => {
    const tx = db.transaction(STORE, "readonly");
    const request = tx.objectStore(STORE).getAll();
    request.onsuccess = () => { resolve(request.result as EvidenceRecord[]); };
    request.onerror = () => { reject(request.error ?? new Error("IndexedDB read failed")); };
  });
  db.close();
  return records.sort((left, right) => right.sequence - left.sequence);
}

export async function nextSequence(): Promise<number> {
  const records = await listEvidence();
  return records.reduce((max, record) => Math.max(max, record.sequence), 0) + 1;
}

export async function hasEvidenceFor(url: string, htmlSha256: string): Promise<boolean> {
  const records = await listEvidence();
  return records.some((record) => record.url === url && record.htmlSha256 === htmlSha256);
}

export async function deleteEvidence(id: string): Promise<void> {
  const db = await openDb();
  await new Promise<void>((resolve, reject) => {
    const tx = db.transaction(STORE, "readwrite");
    tx.objectStore(STORE).delete(id);
    tx.oncomplete = () => { resolve(); };
    tx.onerror = () => { reject(tx.error ?? new Error("IndexedDB delete failed")); };
  });
  db.close();
}

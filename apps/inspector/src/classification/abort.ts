import type { AiChunkReasonCode } from '../core/types.js';

/** Only known run-limit markers are accepted; arbitrary reason values never escape. */
export function cancellationReason(signal: AbortSignal): AiChunkReasonCode {
  return signal.reason === 'TIME_LIMIT' ? 'TIME_LIMIT' :
    signal.reason === 'RESOURCE_LIMIT' ? 'RESOURCE_LIMIT' : 'USER_CANCELLED';
}

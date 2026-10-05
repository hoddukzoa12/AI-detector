# Node CLEF classification

`analyzeCandidate(candidate, apiKey, signal, options?)` returns a terminal
`Promise<AiAnalysis>`. Supply the Node-side `OPENROUTER_API_KEY` value and only call
this module after the caller has checked required CLEF consent and configuration.
The candidate contract is DetectionCandidateV2; an image owner without readable
text is retained for review with ai:null by the caller and is never scheduled.
An empty image candidate also has a defensive no-transport guard here. The module imports Node filesystem/crypto APIs and belongs
only in the Node entrypoint, never renderer or scanned-page code.

Requests always POST to `https://openrouter.ai/api/alpha/decisions`, with model
`cloudflare/clef`, Bearer auth, and `questions.ad_class` of type `choice` whose
criteria object has exactly `illegal_ad`, `general_ad`, `non_ad`, `uncertain`.
The state contains only `rawText`, `normalizedText`, and `links`; page metadata,
HTML, cookies and API credentials do not enter the state. Candidate instructions
are explicitly untrusted evidence. No fallback API/model/local inference is used.

Options are `normalize(rawSlice)`, `stateBudgetTokens` (default/max 1500),
`maxChunks` (default 128, max 1024), `requestTimeoutMs` (default 15000), and
`totalTimeMs` (default 120000), and `maxRequests` (default 1000 per analysis). `fetch` can inject a test transport, which still
receives the fixed endpoint. Supply detection's `normalizeText` to reconstruct
normalization per raw slice. Without a callback, a normalized candidate that needs
splitting is retained as RESOURCE_LIMIT rather than using an invented mapping.
Raw ranges are UTF-16 half-open offsets and preserve the entire original. All links
are included in each measured state; excess links produce an unstarted full range.
Raw and normalized input have a 1,000,000-code-unit work bound and combined links a
65,536-code-unit/1024-link bound. These limits never serve as token estimates.

`planCandidateChunks` and `countStateTokens` expose the exact planning/counting
used by requests. The pinned tokenizer/config and upstream Apache-2.0 license are
in `resources/`; its README explains attribution and bundled resource placement.
The real tokenizer measures `JSON.stringify(state)`, including keys, escaping and
all links. Requests and response streams have time limits; responses have a 64KiB
bound. Aborting cancels transport/reader work, leaves every range terminal, and
ignores late transport completion. Exact AbortSignal reasons `TIME_LIMIT` and
`RESOURCE_LIMIT` preserve those codes, with a running chunk cancelled and pending
chunks not_started. Any other reason maps to USER_CANCELLED; its content is never
recorded. The module's total deadline maps to TIME_LIMIT.

`onProgress(analysis)` is an optional synchronous observer. It receives the initial
complete range plan, running/completed/error/cancelled transitions, and a final
snapshot after pending cleanup. Every snapshot follows `createAiAnalysis` summary
selection and contains isolated copies of all chunks and probabilities; modifying
a snapshot cannot change inputs, later snapshots or the returned analysis. A
completed positive is published before starting another request, so the caller can
preserve a confirmed finding immediately. An observer may abort the supplied
signal to stop further requests. Responses that lose the cancellation race never
publish a positive completion. Observer exceptions are ignored without changing
classification status; observers must handle their own runtime reporting. The
empty-image/pre-aborted path emits one terminal snapshot and makes no HTTP request.

Responses validate exact model/type/choice, four finite probabilities in [0,1]
with sum tolerance .001 and a highest-probability choice, separate confidence,
nonnegative integer input/output token usage, and optional nonnegative finite cost.
Only contract-defined chunk decisions are retained; response bodies, key values,
provider errors and exceptions are never copied into the returned analysis.
HTTP/response/timeout failures remain explicit; unfinished ranges stay reviewable.
`createAiAnalysis` selects one actual representative chunk with the core policy;
`classifyAiAnalysis` uses default .8 to confirm a positive while preserving review
for errors or unfinished/uncertain coverage. Finding generation and deduplication
remain the caller's responsibility. These calls can incur service charges; this
module does not assert a price or a retention policy.

Tests use a local mock HTTP server and injected transports; no real inference call
or real API credential was used.

`reserveRequest(): boolean` is a synchronous atomic permit supplied by the caller
for the shared run request budget. It is checked immediately before each actual
transport invocation, after progress, key, deadline and cancellation guards. False
stops this candidate with RESOURCE_LIMIT and not_started remaining ranges. The
local maxRequests cap also counts actual starts. A permit is not a request count:
a permit callback may stop the run, and the subsequent guard then starts no HTTP.
`onRequestStart(): void` runs once immediately after transport invocation, including
synchronous transport throws, so requestCounts records actual starts. Observer
exceptions are isolated; cancellation from that observer means an actual started
request is cancelled. Cancellation from running progress starts no request and
consumes no permit. A fetch wrapper may alternatively count starts itself.
CLEF retains its existing zero-retry policy; HTTP failures are explicit review,
and every attempted transport is subject to these bounds.

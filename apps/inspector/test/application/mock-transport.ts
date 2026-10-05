/** Explicit test-only transport; exercises the production CLEF adapter and parser. */
export const positiveClef: typeof fetch = async () => new Response(JSON.stringify({ model: 'cloudflare/clef', usage: { input_tokens: 10, output_tokens: 1 },
  answers: { ad_class: { type: 'choice', choice: 'illegal_ad', confidence: .9, probabilities: { illegal_ad: .9, general_ad: 1/30, non_ad: 1/30, uncertain: 1/30 } } } }));
export const mockAnalysisOptions = { apiKey: 'unit-test-credential', aiOptions: { fetch: positiveClef } };

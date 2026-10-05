# CLEF tokenizer attribution

Tokenizer data and configuration are from Cloudflare's public `Cloudflare/clef`
Hugging Face repository, revision `2f3de3dd85f379784083b0814d997ab627200f0c`.
Source: https://huggingface.co/Cloudflare/clef/tree/2f3de3dd85f379784083b0814d997ab627200f0c

Distributed under Apache License 2.0; the upstream LICENSE is preserved here.
`provenance.json` records immutable source URLs, exact file sizes and SHA-256 hashes.
Only tokenizer data, configuration, and license were downloaded. No model weights,
remote code, inference engine, or chat template is executed. The JSON/config are
loaded by @huggingface/tokenizers 0.2.0 in Node and their hashes checked at load.

A bundled entrypoint must have this directory copied to its adjacent `resources/`
directory because the loader resolves `./resources/` relative to import.meta.url.
Runtime requires no Hugging Face access. Token counts encode exact serialized state
with add_special_tokens false, independently of any provider chat-template overhead.
The default state budget is 1500 tokens; the service truncates at approximately
2000 state tokens. This budget does not assert any billing price or server retention.

# CKB trademark and conformance policy

"CKB", "Codebase Knowledge Base" and "CKB-compatible" (the **Marks**) are trademarks of Riddhi Mohan Sharma. This policy keeps the specification a single, trustworthy standard. The license (CC BY-ND 4.0) covers the specification text and schemas. This policy covers the names.

## You may, without asking
- Implement the specification, as a producer or a consumer, in any software, including commercial software.
- Say your software "reads CKB" or "writes CKB v0.2", as long as it does so accurately.
- Call your software **"CKB-compatible (v0.X)"**, but only if, for that exact version:
  - artifacts it produces pass the official conformance suite (`tests/validate.sh` in this repository); or
  - it correctly ingests the official examples (`schema/v0.X/examples/`) without loss.
- Link to the specification and redistribute it **unmodified** with attribution.

## You may not, without written permission
- Publish a modified, extended or forked version of the specification, or call any modified format "CKB", "CKB-compatible", or a confusingly similar name (e.g. "CKB+", "OpenCKB", "CKB Extended").
- Add normative fields, entity types, relation kinds or rules and present them as part of CKB. Vendor data belongs in `x-` extension fields, which carry no conformance meaning.
- Use the Marks in a product, company or domain name, or in a way that suggests endorsement by, or affiliation with, the specification's author.
- Claim conformance for software that fails the conformance suite.

## Proposing changes
Open an issue in this repository describing the expressiveness gap, with a minimal example. Only the author publishes new versions of the specification. Accepted contributions require the Contributor License Agreement (see CONTRIBUTING.md).

## Contact
For permissions and licensing, open an issue titled "Trademark/licensing request" or contact the author through GitHub (@riddhimohansharma).

*This policy does not replace legal advice.*

# Verification modes

Centra provides two explicit verification modes. The selected mode is stored in the profile and may be changed from the scan policy screen at any time.

## Full verification

Full verification reads every accepted file and calculates every selected digest again. This is the authoritative integrity check and the recommended mode for releases, incident response, and security-sensitive production verification.

## Fast verification

Fast verification is an optimization for frequent routine checks. A digest may be reused from a trusted baseline only when:

- the trusted baseline signature and public key have already been verified;
- all requested algorithms exist in the baseline record;
- file size, modification time, mode, and symbolic-link target match;
- the baseline record is not marked unstable.

Any mismatch causes the file to be read and hashed normally. New and removed paths are still detected by the inventory comparison.

Fast verification is weaker than full verification because unchanged metadata does not prove unchanged content. The interface therefore labels the mode as weaker and never presents it as equivalent to a full content scan.

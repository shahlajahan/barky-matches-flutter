# Is Bank / NestPay Implementation Specification

This file is the local implementation specification for the Is Bank Sanal POS work.
It is derived only from the vendor PDFs and official sample code in
`docs/payment/vendor/`.

If a rule is not explicitly stated in the vendor PDFs, this document marks it as
`UNKNOWN`. Do not fill gaps from internet examples or legacy guides.

## Source Documents Read

- `hash-v3-spec.pdf` - NestPay Hash Version 3 documentation.
- `nestpay-api.pdf` - NestPay API/XML integration documentation.
- `nestpay-3d.pdf` - NestPay Merchant Integration 3D documentation.
- `nestpay-3d-pay.pdf` - NestPay 3D Pay documentation.
- `nestpay-3d-pay-hosting.pdf` - NestPay 3D Pay Hosting documentation.
- `hash-v3-sample-code/Sample Codes/3D_PAY_HOSTING/PHP/*` - official Hash V3
  3D Pay Hosting PHP sample request/response handlers.
- `hash-v3-sample-code/Sample Codes/3D_PAY_HOSTING/JSP/*` - official Hash V3
  3D Pay Hosting JSP sample request/response handlers.
- `hash-v3-sample-code/Sample Codes/3D_PAY_HOSTING/C#.NET/*` - official Hash V3
  3D Pay Hosting C# sample request/response handlers.

## Payment Products

| Product | Source | Implementation relevance |
| --- | --- | --- |
| API/XML payment | `nestpay-api.pdf`, XML request/response and `/fim/api` examples | Not the selected first implementation product. Useful for later non-hosted API operations only. |
| 3D | `nestpay-3d.pdf`, Merchant Integration 3D | Not the selected product. Contains shared 3D gateway/callback field references. |
| 3D Pay | `nestpay-3d-pay.pdf`, 3D Pay documentation | Not the selected product. |
| 3D Pay Hosting | `nestpay-3d-pay-hosting.pdf`, 3D Pay Hosting documentation | Selected hosted payment product. |
| Hash Version 3 | `hash-v3-spec.pdf`, sections `2 Hash Version 3` and `3 Hash Version 3 Ornek Kodlar` | Required hash algorithm/reference for request hash generation. |

## Selected Product

Selected product: `3D Pay Hosting`.

Source: `nestpay-3d-pay-hosting.pdf`, document title and request examples;
official Hash V3 sample code under `Sample Codes/3D_PAY_HOSTING/`.

## Required URLs

| URL | Purpose | Source |
| --- | --- | --- |
| `https://[host_name]/fim/est3dgate` | Hosted 3D gateway form POST target. | `nestpay-3d-pay-hosting.pdf`, section `1.1 Gonderilen Gizli Parametreler`. |
| `/fim/api` | XML/API endpoint path. | `nestpay-api.pdf`, API examples using `processTransaction("host", 443, "/fim/api")`. |
| `okUrl` | Merchant success return URL sent in gateway request. | `nestpay-3d-pay-hosting.pdf`, Appendix A `Gecit Parametreleri`, required parameters. |
| `failUrl` | Merchant failure return URL sent in gateway request. | `nestpay-3d-pay-hosting.pdf`, Appendix A `Gecit Parametreleri`, required parameters. |

`callbackUrl` appears in the Hash Version 3 PDF sample request and in every
official 3D Pay Hosting sample request page reviewed.

Source: `hash-v3-spec.pdf`, section `2 Hash Version 3` sample request;
`PHP/ver3RequestExample.php`, `JSP/ver3RequestExample.jsp`,
`C#.NET/ver3RequestExample.aspx`.

## Required Secrets

| Secret | Required for | Source |
| --- | --- | --- |
| Merchant/client ID (`clientid` / `clientId`) | Gateway request field and hash input. | `nestpay-3d-pay-hosting.pdf`, section `1.1`; `hash-v3-spec.pdf`, section `2 Hash Version 3` sample request. |
| Store key (`storeKey`) | Hash input secret. | `hash-v3-spec.pdf`, section `2 Hash Version 3` sample request and plaintext example. |
| API username/name (`Name`) | XML/API requests only. | `nestpay-api.pdf`, XML request example. |
| API password (`Password`) | XML/API requests only. | `nestpay-api.pdf`, XML request example. |

Whether API username/password are required for the selected 3D Pay Hosting start
request is `UNKNOWN`; the selected hosted form examples do not show them.

## Required Request Fields

For 3D Pay Hosting, the vendor document lists hidden parameters sent to
`https://[host_name]/fim/est3dgate`.

Source: `nestpay-3d-pay-hosting.pdf`, section `1.1 Gonderilen Gizli Parametreler`
and Appendix A `Gecit Parametreleri`.

| Field | Required | Notes |
| --- | --- | --- |
| `clientid` | Yes | Alphanumeric, maximum 15 characters in Appendix A. |
| `storetype` | Yes | Official Hash V3 sample code uses `3D_PAY_HOSTING`. PDF examples also show `3d_pay_hosting`; see contradictions section. |
| `hash` | Yes | Request hash value. |
| `hashAlgorithm` / `hashalgorithm` | Yes | Official Hash V3 sample request pages use `hashAlgorithm=ver3`; PDF required-list text shows `hashalgorithm`. |
| `TranType` | Yes | Official Hash V3 3D Pay Hosting sample request pages use `TranType=Auth`. PDF 3D Pay Hosting examples also show `islemtipi`/`trantype`; see contradictions section. |
| `Instalment` | Included by official sample | Official sample sends an empty `Instalment` field and includes it in hash calculation. |
| `amount` | Yes | Payment amount. |
| `currency` | Yes | ISO numeric currency code; TL is `949`. |
| `oid` | Yes in PDF Appendix A | Order ID, alphanumeric, maximum 64 characters in Appendix A. Official Hash V3 3D Pay Hosting sample request pages reviewed do not send `oid`; see contradictions section. |
| `okUrl` | Yes | Success return URL. |
| `failUrl` | Yes | Failure return URL. |
| `lang` | Yes | Language; examples include `en` and `tr`. |
| `rnd` | Yes in examples and Appendix A | Random string; Appendix A says fixed length 20 characters. |
| `callbackUrl` | Included by official Hash V3 sample | Official sample request pages send callback URL and include it in hash calculation. |
| `BillToName` | Included by official Hash V3 sample | Included in all reviewed 3D Pay Hosting sample request pages. |
| `BillToCompany` | Included by official Hash V3 sample | Included in all reviewed 3D Pay Hosting sample request pages. |
| `refreshtime` | Included by official Hash V3 sample | Included in all reviewed 3D Pay Hosting sample request pages. |

Optional/additional request fields shown in vendor examples or Appendix A:

| Field | Source | Notes |
| --- | --- | --- |
| `refreshtime` | `nestpay-3d-pay-hosting.pdf`, Appendix A | Redirect time in seconds to `failUrl`. |
| `encoding` | `nestpay-3d-pay-hosting.pdf`, request example and Appendix A | Example uses `utf-8`; max 32 characters. |
| `description` | `nestpay-3d-pay-hosting.pdf`, Appendix A | Max 255 characters. |
| Basket/item fields such as `ProductCode1`, `Id1`, `Price1`, `Total1` | `nestpay-3d-pay-hosting.pdf`, request examples | Optional cart/product detail fields. |
| Billing/shipping fields | `nestpay-3d-pay-hosting.pdf`, request examples | Optional customer detail fields. |
| `callbackUrl` | `hash-v3-spec.pdf`, section `2 Hash Version 3`; official `ver3RequestExample` files | Included in official Hash V3 3D Pay Hosting samples. |

## Currency Codes

| Code | Meaning | Source |
| --- | --- | --- |
| `949` | Turkish Lira / TL | `nestpay-3d-pay-hosting.pdf`, section `1.1` and Appendix A `currency`. |

Other currency codes are `UNKNOWN` from the reviewed implementation-relevant
sections.

## Store Types

| Store type | Source | Notes |
| --- | --- | --- |
| `3D_PAY_HOSTING` | Official Hash V3 `ver3RequestExample` files | Selected product store type used by the official sample code. |
| `3d_pay_hosting` | `nestpay-3d-pay-hosting.pdf`, 3D Pay Hosting request example | Lowercase PDF example value; see contradictions section. |
| `3d` / `3D` | `nestpay-3d-pay-hosting.pdf`, examples; `hash-v3-spec.pdf`, sample request uses `storeType 3D` | Used in non-hosting/shared examples. Not the selected product value. |

The complete allowed store-type enumeration remains `UNKNOWN`.

## Hash Version 3

Hash Version 3 is the selected request hash version.

Source: `hash-v3-spec.pdf`, section `2 Hash Version 3`.

Rules explicitly present in the vendor Hash V3 document:

| Rule | Source |
| --- | --- |
| `hashAlgorithm` is sent as `ver3` in the sample request. | `hash-v3-spec.pdf`, section `2 Hash Version 3` sample request. |
| Hash output in the sample is `Base64(SHA512(plaintext))`. | `hash-v3-spec.pdf`, section `2 Hash Version 3` plaintext/hash example. |
| The store key is appended as the final value in the sample hash plaintext. | `hash-v3-spec.pdf`, section `2 Hash Version 3` sample order and plaintext example. |
| In hash calculation values, `\` is escaped as `\\` and `|` is escaped as `\|`. | `hash-v3-spec.pdf`, section `2 Hash Version 3`, Important Note with `ORDER-256712jbs\j6b|` example. |
| Hash Version 1 must not be used. | `hash-v3-spec.pdf`, section after `2.2`, note about Hash Version 1 and 2. |
| Request and response/callback samples both calculate `Base64(SHA512(hashInput))`. | Official `GenericVer3RequestHashHandler` and `GenericVer3ResponseHandler` files in PHP, JSP, and C#. |
| Request and response/callback samples both sort parameters by parameter name case-insensitively. | Official `GenericVer3RequestHashHandler` and `GenericVer3ResponseHandler` files in PHP, JSP, and C#. |
| Request and response/callback samples both exclude `hash` and `encoding` case-insensitively from the hash input. | Official `GenericVer3RequestHashHandler` and `GenericVer3ResponseHandler` files in PHP, JSP, and C#. |
| C# samples additionally exclude `countdown`. | Official C# `GenericVer3RequestHashHandler.aspx` and `GenericVer3ResponseHandler.aspx`. |

## Hash Generation

Documented Hash V3 sample request fields:

Source: `hash-v3-spec.pdf`, section `2 Hash Version 3` sample request.

```text
clientId=100200127
amount=95.93
okurl=http://localhost:8080/SampleCodeJSPTest/GenericVer3ResponseHandler
failUrl=http://localhost:8080/SampleCodeJSPTest/GenericVer3ResponseHandler
TranType=Auth
Instalment=
callbackUrl=http://localhost:8080/SampleCodeJSPTest/GateResponseControl.jsp
currency=949
rnd=87954458746
storeType=3D
lang=tr
hashAlgorithm=ver3
BillToName=name
BillTocompany=billToCompany
refreshTime=5
storeKey=TEST1234
```

Documented sample order of used parameters:

Source: `hash-v3-spec.pdf`, section `2 Hash Version 3` sample order.

```text
amount|BillToCompany|BillToName|callbackUrl|clientid|currency|failUrl|hashAlgorithm|Instalment|lang|okurl|refreshtime|rnd|storetype|TranType|storeKey
```

Documented plaintext example:

Source: `hash-v3-spec.pdf`, section `2 Hash Version 3` plaintext/hash example.

```text
95.93|billToCompany|name|http://localhost:8080/SampleCodeJSPTest/GateResponseControl.jsp|100200127|949|http://localhost:8080/SampleCodeJSPTest/GenericVer3ResponseHandler|ver3||tr|http://localhost:8080/SampleCodeJSPTest/GenericVer3ResponseHandler|5|87954458746|3D|Auth|TEST1234
```

Hash formula:

Source: `hash-v3-spec.pdf`, section `2 Hash Version 3` plaintext/hash example.

```text
Hash3 = Base64(SHA512(plaintext))
```

Resolved implementation rules from the official sample code:

- Build the hash input from posted parameter values, not `name=value` pairs.
- Sort posted parameter names case-insensitively before appending values.
  PHP uses `natcasesort`; JSP compares `toUpperCase(Locale.US)` keys; C# compares
  `ToLower(en-US)` keys.
- For each sorted parameter, append the escaped value plus `|`.
- Exclude parameters whose lowercase name is `hash` or `encoding`.
- C# samples also exclude lowercase `countdown`; PHP and JSP samples do not.
- Escape each parameter value by replacing `\` with `\\`, then `|` with `\|`.
- Escape `storeKey` the same way.
- Append escaped `storeKey` as the final hash input segment with no trailing
  delimiter after it.
- Calculate SHA-512 over the resulting hash input and Base64-encode the digest.
- Do not implement Hash Version 1.

## Required Callback Fields

The 3D/3D Pay Hosting documents list response fields sent back by NestPay.
The exact requiredness of each callback field is `UNKNOWN`; treat this as the
documented callback field set, not a guaranteed required set.

Source: `nestpay-3d-pay-hosting.pdf`, section `2.3 Hash Kontrol`, response
parameter table and MPI parameter table. The same field table also appears in
`nestpay-3d.pdf`.

| Field | Meaning / format from vendor doc |
| --- | --- |
| `AuthCode` | Authorization code, 6 characters. |
| `Response` | Payment status. Exact allowed values for selected 3D callback are `UNKNOWN`. |
| `HostRefNum` | Bank reference code, 12 characters. |
| `ProcReturnCode` | Status code, 2 characters. Exact meaning table is `UNKNOWN`. |
| `TransId` | Maximum 64 characters. |
| `ErrMsg` | Error message, maximum 255 characters. |
| `ClientIp` | Maximum 15 characters. |
| `ReturnOid` | Returned order ID, maximum 64 characters. |
| `MaskedPan` | Masked card number, 12 characters; example format `XXXXXX***XXX`. |
| `EXTRA.TRXDATE` | Transaction date, 17 characters, format `yyyyMMdd HH:mm:ss`. |
| `rnd` | Fixed length, 20 characters. |
| `HASHPARAMS` | Legacy/3D Pay Hosting PDF hash-control field. Not used by the official Hash V3 `GenericVer3ResponseHandler` samples reviewed. |
| `HASHPARAMSVAL` | Legacy/3D Pay Hosting PDF hash-control value field. Not used by the official Hash V3 `GenericVer3ResponseHandler` samples reviewed. |
| `HASH` | Callback hash field read by official Hash V3 response handlers and compared with locally calculated Hash V3 value. |
| `mdStatus` | MPI/3D status field. Exact meaning table is `UNKNOWN` from extracted text. |
| `merchantID` | MPI parameter. Format/meaning beyond field name is `UNKNOWN`. |
| `sID` | MPI parameter; extracted table says Visa is `1`, Mastercard is `2`. |
| `MdErrorMsg` | MPI error message, maximum 512 characters. |

## Callback Validation

Callback validation is specified by the official Hash V3 sample response
handlers for 3D Pay Hosting.

Source: official `GenericVer3ResponseHandler` files under
`docs/payment/vendor/hash-v3-sample-code/Sample Codes/3D_PAY_HOSTING/` for PHP,
JSP, and C#.

The response handler behavior is:

- Read all posted callback parameters.
- Sort parameter names case-insensitively.
- Build the hash input from sorted parameter values only.
- Escape each value by replacing `\` with `\\`, then `|` with `\|`.
- Exclude parameters named `hash` or `encoding`, case-insensitively.
- C# additionally excludes `countdown`; PHP and JSP do not.
- Escape `storeKey` with the same escaping rule.
- Append escaped `storeKey` as the final value.
- Calculate `Base64(SHA512(hashInput))`.
- Read posted `HASH`.
- Accept the callback hash only when calculated hash equals posted `HASH`.

The response/callback hash therefore uses the same core Hash V3 algorithm as the
request hash in the official samples: sorted posted fields, excluded
`hash`/`encoding`, escaped values, appended escaped store key, SHA-512, Base64.

`HASHPARAMS` and `HASHPARAMSVAL` are not used by the official Hash V3
`GenericVer3ResponseHandler` samples reviewed. This contradicts the older
3D Pay Hosting PDF `2.3 Hash Kontrol` field list unless that field list is for a
legacy/non-Hash-V3 flow.

UNKNOWN:

- Whether production Is Bank callbacks can include `countdown` for all stacks and
  whether it must be excluded outside C# implementations.
- Whether `HASH` field casing is always uppercase in callbacks. The response
  handlers retrieve `HASH`; the exclusion check treats `hash` case-insensitively.

## mdStatus Table

Source checked: `nestpay-3d-pay-hosting.pdf`, section `2.3 Hash Kontrol`, MPI
parameter table; `nestpay-3d.pdf`, corresponding MPI parameter table.

| mdStatus | Meaning |
| --- | --- |
| `1` | UNKNOWN from extracted vendor text. |
| `2` | UNKNOWN from extracted vendor text. |
| `3` | UNKNOWN from extracted vendor text. |
| `4` | UNKNOWN from extracted vendor text. |
| Other values | UNKNOWN from extracted vendor text. |

The extracted PDF text shows `mdStatus` and a partial format/range fragment, but
does not provide a reliable meaning table. Do not infer meanings.

## ProcReturnCode Meanings

Source checked: `nestpay-3d-pay-hosting.pdf`, callback response field table;
`nestpay-3d.pdf`, callback response field table; `nestpay-api.pdf`, response
property examples.

Known:

- `ProcReturnCode` is a status code field.
- Its format is 2 characters / 2 digits in the extracted tables.

UNKNOWN:

- Which code means success.
- Which codes mean declined, bank error, system error, or retryable failure.
- Whether `00` means approved for selected 3D Pay Hosting callbacks.

Do not infer `ProcReturnCode` success/failure semantics without an explicit
vendor table or bank confirmation.

## Approved Meanings

Source: `nestpay-api.pdf`, XML response example.

The API/XML document shows:

```xml
<Response>{Approved, Declined, Error}</Response>
```

For selected 3D Pay Hosting callback handling:

- Whether `Response=Approved` alone is sufficient to mark payment successful is
  `UNKNOWN`.
- Whether success also requires a specific `ProcReturnCode`, `mdStatus`, and
  valid callback hash is `UNKNOWN`. The official response handlers validate only
  the hash and print success/failure; they do not implement final payment
  approval semantics.

Implementation rule: callback hash validation is resolved by the official Hash
V3 response handler. Final payment approval semantics still require explicit
business rules/bank confirmation.

## Error Codes

Source checked: all vendor PDFs listed above.

Known fields:

- `ErrMsg` appears as an error message field with max 255 characters in 3D
  callback tables.
- XML/API examples expose `ErrMsg`/`errmsg` and `ProcReturnCode`.

UNKNOWN:

- Complete error-code list.
- Mapping from `ProcReturnCode` values to meanings.
- Retryability of each error.
- User-displayable vs internal-only error classification.

## Request Examples

### Official Hash V3 3D Pay Hosting pre-hash form

Source: official `PHP/ver3RequestExample.php`, `JSP/ver3RequestExample.jsp`,
and `C#.NET/ver3RequestExample.aspx`.

```html
<form method="post" action="https://host/GenericVer3RequestHashHandler">
  <input type="hidden" name="clientid" value="100200127">
  <input type="hidden" name="amount" value="91.96">
  <input type="hidden" name="okurl" value="https://host/GenericVer3ResponseHandler">
  <input type="hidden" name="failUrl" value="https://host/GenericVer3ResponseHandler">
  <input type="hidden" name="TranType" value="Auth">
  <input type="hidden" name="Instalment" value="">
  <input type="hidden" name="callbackUrl" value="https://host/callback.php">
  <input type="hidden" name="currency" value="949">
  <input type="hidden" name="rnd" value="...">
  <input type="hidden" name="storetype" value="3D_PAY_HOSTING">
  <input type="hidden" name="lang" value="tr">
  <input type="hidden" name="hashAlgorithm" value="ver3">
  <input type="hidden" name="BillToName" value="name">
  <input type="hidden" name="BillToCompany" value="billToCompany">
  <input type="hidden" name="refreshtime" value="5">
</form>
```

Note: the official Hash V3 `ver3RequestExample` files post to
`GenericVer3RequestHashHandler`, which calculates `hash` and then forwards the
form to the 3D gateway.

### Official GenericVer3RequestHashHandler behavior

Source: official `PHP/GenericVer3RequestHashHandler.php`,
`JSP/GenericVer3RequestHashHandler.jsp`, and
`C#.NET/GenericVer3RequestHashHandler.aspx`.

```text
1. Read every posted form field.
2. Re-render each posted field as a hidden field for forwarding.
3. Sort parameter names case-insensitively.
4. For each sorted parameter except hash/encoding, append escaped value + "|".
5. C# also excludes countdown.
6. Append escaped storeKey.
7. Calculate Base64(SHA512(hashInput)).
8. Add the calculated hash field.
9. Auto-submit to https://<host_address>/<3dgate_path>.
```

### Official GenericVer3ResponseHandler behavior

Source: official `PHP/GenericVer3ResponseHandler.php`,
`JSP/GenericVer3ResponseHandler.jsp`, and
`C#.NET/GenericVer3ResponseHandler.aspx`.

```text
1. Read every posted callback field.
2. Sort parameter names case-insensitively.
3. For each sorted parameter except hash/encoding, append escaped value + "|".
4. C# also excludes countdown.
5. Append escaped storeKey.
6. Calculate Base64(SHA512(hashInput)).
7. Compare calculated hash with posted HASH.
8. Treat equality as successful hash validation; mismatch is a security alert.
```

### Hash Version 3 request hash example

Source: `hash-v3-spec.pdf`, section `2 Hash Version 3`.

```text
hashAlgorithm=ver3
plaintext=95.93|billToCompany|name|http://localhost:8080/SampleCodeJSPTest/GateResponseControl.jsp|100200127|949|http://localhost:8080/SampleCodeJSPTest/GenericVer3ResponseHandler|ver3||tr|http://localhost:8080/SampleCodeJSPTest/GenericVer3ResponseHandler|5|87954458746|3D|Auth|TEST1234
hash=Base64(SHA512(plaintext))
```

### XML/API request example

Source: `nestpay-api.pdf`, XML request example.

```xml
<CC5Request>
  <Name>...</Name>
  <Password>...</Password>
  <ClientId>600100000</ClientId>
  <IPAddress>1.1.1.1</IPAddress>
  <Mode>P</Mode>
  <OrderId>...</OrderId>
  <Type>Auth</Type>
  <Total>180</Total>
  <Currency>949</Currency>
</CC5Request>
```

This XML/API request is not the selected first implementation product.

## Callback Examples

No complete selected-product callback payload example was reliably extracted
from the vendor PDFs or sample code.

Documented callback/response field example set:

Source: `nestpay-3d-pay-hosting.pdf`, section `2.3 Hash Kontrol`, response and
MPI parameter tables.

```text
AuthCode=...
Response=...
HostRefNum=...
ProcReturnCode=...
TransId=...
ErrMsg=...
ClientIp=...
ReturnOid=...
MaskedPan=...
EXTRA.TRXDATE=yyyyMMdd HH:mm:ss
rnd=...
HASHPARAMS=...
HASHPARAMSVAL=...
HASH=...
mdStatus=...
merchantID=...
sID=...
MdErrorMsg=...
```

Full callback example: `UNKNOWN`. Callback hash validation flow is resolved by
the official `GenericVer3ResponseHandler` samples.

## Sample Code Review Results

### Newly resolved items

| Item | Resolution | Source |
| --- | --- | --- |
| Request hash algorithm | `Base64(SHA512(hashInput))`. | Official PHP/JSP/C# `GenericVer3RequestHashHandler` files. |
| Response/callback hash algorithm | `Base64(SHA512(hashInput))`. | Official PHP/JSP/C# `GenericVer3ResponseHandler` files. |
| Request parameter ordering | Sort parameter names case-insensitively before appending values. | Official PHP/JSP/C# `GenericVer3RequestHashHandler` files. |
| Callback parameter ordering | Sort parameter names case-insensitively before appending values. | Official PHP/JSP/C# `GenericVer3ResponseHandler` files. |
| Request excluded fields | Exclude `hash` and `encoding` case-insensitively; C# also excludes `countdown`. | Official PHP/JSP/C# `GenericVer3RequestHashHandler` files. |
| Callback excluded fields | Exclude `hash` and `encoding` case-insensitively; C# also excludes `countdown`. | Official PHP/JSP/C# `GenericVer3ResponseHandler` files. |
| Escaping | Replace `\` with `\\`, then `|` with `\|` for each value and store key. | Official PHP/JSP/C# request/response handlers; `hash-v3-spec.pdf`, section `2 Hash Version 3`. |
| Store key placement | Append escaped store key as the final hash input segment. | Official PHP/JSP/C# request/response handlers. |
| `HASHPARAMS` flow | Not used by official Hash V3 response handler samples. | Official PHP/JSP/C# `GenericVer3ResponseHandler` files. |
| Selected sample store type | `3D_PAY_HOSTING`. | Official PHP/JSP/C# `ver3RequestExample` files. |
| Sample transaction field | `TranType=Auth`. | Official PHP/JSP/C# `ver3RequestExample` files. |
| Callback validation flow | Recompute Generic Hash V3 over callback POST fields and compare with posted `HASH`. | Official PHP/JSP/C# `GenericVer3ResponseHandler` files. |

### Still unknown items

| Item | Why still unknown |
| --- | --- |
| Complete `mdStatus` meaning table | Vendor PDFs expose `mdStatus`, but the reviewed extracted text and sample handlers do not provide a reliable meaning table. |
| Complete `ProcReturnCode` meaning table | Vendor PDFs/sample handlers expose the field, but do not provide a reliable code-to-meaning table in reviewed material. |
| Final payment approval rule | Sample response handlers validate only hash equality and do not define whether success requires `Response=Approved`, `ProcReturnCode`, `mdStatus`, or a combination. |
| Complete error-code list | Reviewed PDFs and samples expose `ErrMsg`, but not a complete error-code catalog. |
| Full real callback payload | Sample response handlers print arbitrary POST fields but do not include a complete captured 3D Pay Hosting callback example. |
| `countdown` exclusion portability | C# request/response handlers exclude `countdown`; PHP/JSP handlers do not. |
| Exact accepted casing for `HASH` on callback | Response handlers retrieve `HASH`, while exclusion checks are case-insensitive for `hash`. |

### Contradictions found

| Area | PDF / earlier source | Official Hash V3 sample code | Handling in this spec |
| --- | --- | --- | --- |
| Callback hash validation | `nestpay-3d-pay-hosting.pdf` section `2.3 Hash Kontrol` lists `HASHPARAMS`, `HASHPARAMSVAL`, and `HASH`. | `GenericVer3ResponseHandler` ignores `HASHPARAMS`/`HASHPARAMSVAL` and validates by recomputing Generic Hash V3 over posted fields, excluding `hash`/`encoding`. | Prefer official Hash V3 sample code for Hash V3 callback validation; keep `HASHPARAMS` fields documented as legacy/PDF fields. |
| Store type casing/value | PDF examples include `3d_pay_hosting`; Hash V3 PDF generic sample uses `3D` for a non-hosting sample. | Official 3D Pay Hosting samples use `3D_PAY_HOSTING`. | Use `3D_PAY_HOSTING` for selected Hash V3 3D Pay Hosting implementation. |
| Transaction type field name | PDF examples show `islemtipi`/`trantype` in some sections. | Official Hash V3 3D Pay Hosting samples use `TranType`. | Use `TranType` for Hash V3 3D Pay Hosting sample-compatible requests. |
| `oid` | `nestpay-3d-pay-hosting.pdf` Appendix A lists `oid` as required. | Official Hash V3 3D Pay Hosting `ver3RequestExample` files reviewed do not send `oid`. | Keep `oid` as PDF-required but flag the sample-code omission as a bank question. |
| `countdown` | PDF and PHP/JSP sample handlers reviewed do not define a `countdown` exclusion. | C# request and response handlers exclude `countdown`. | Mark portability of `countdown` exclusion as `UNKNOWN`. |

### Required questions for Is Bank

1. For Hash V3 3D Pay Hosting production requests, is `oid` required even though
   official `ver3RequestExample` files omit it?
2. Should callback validation always ignore `countdown`, or is that C# sample
   exclusion environment-specific?
3. Is `HASH` always returned uppercase, or should callback handlers accept
   alternate casing?
4. What exact combination of `HASH`, `Response`, `ProcReturnCode`, and
   `mdStatus` constitutes final payment approval?
5. Provide the official `mdStatus` and `ProcReturnCode` meaning tables for Is
   Bank 3D Pay Hosting.
6. Confirm whether `HASHPARAMS` / `HASHPARAMSVAL` are legacy-only for Hash V3
   integrations.

## Implementation Guardrails

- Use Hash Version 3 for request hash generation.
- Generate request hash as `Base64(SHA512(plaintext))` using the documented
  Hash V3 escaping rule for `\` and `|`.
- Use `3D_PAY_HOSTING` as the selected hosted product store type per the
  official Hash V3 sample code.
- Validate callback hash with the official Hash V3 response handler behavior:
  sort posted parameters case-insensitively, exclude `hash`/`encoding`, escape
  values, append escaped store key, calculate `Base64(SHA512(...))`, and compare
  with posted `HASH`.
- Do not infer `mdStatus`, `ProcReturnCode`, or `Response=Approved` success
  semantics beyond what is explicitly documented here.

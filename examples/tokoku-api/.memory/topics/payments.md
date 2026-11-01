# Payments

## Overview
Shops take cash, cards and QRIS. Cash is recorded at the till only; cards and QRIS go through one
payment gateway, and the money reaches the shop owner in the nightly settlement. The code lives in
`src/payments/`; the settlement part is frozen until the bank audit ends (decisions.md).

## How it works
1. The tablet starts a payment with `POST /payments`; `src/payments/gateway.ts` creates a charge at the
   gateway and returns the QR code or card terminal request.
2. The gateway calls `POST /payments/webhook` when the payment succeeds or fails. The handler checks
   the signature with `PAYMENT_GATEWAY_KEY` and marks the sale as paid. The webhook can arrive twice;
   the handler ignores a payment it has already marked.
3. At 02:00 WIB the `settle-daily` job (`src/payments/settlement/settle-daily.ts`) adds up each shop's
   paid card and QRIS sales of the previous day, subtracts the gateway fee (`calc.ts`) and sends the
   payout to the shop's bank account.

## Rules and pitfalls
- Amounts are whole rupiah (`Money`); the gateway sends strings such as `"15000.00"`, so parse them with `Money.fromGateway()`.
- Never mark a sale as paid from the tablet's own report; only the webhook is trusted, because a tablet can lose its connection after the customer cancels.
- Payout differences are usually the gateway fee; see gotchas.md before changing `calc.ts`.

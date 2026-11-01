# Glossary

- **Member aktif** — a shop customer with a sale in the last 90 days; signing up or logging in does not count. #member (user)
- **Nota retur** — a return of goods to a supplier, with its own number; it cites the supplier's original invoice and is refused after 30 days. Not a customer refund. @src/returns/ (user)
- **Owner** — the shop's owner account, the only one that sees payouts and supplier prices; staff accounts only use the till. #owner (user)
- **PO** — Purchase Order from a shop to a supplier, not a pre-order from a customer. Table `purchase_orders`. #po @src/purchase-orders/ (user)
- **Settlement** — the nightly payout of a shop's card and QRIS sales to its bank account, H+1 working day; not the payment of a supplier invoice. @src/payments/settlement/ (user)
- **Stok opname** — a stock count in the shop; differences are saved as ledger adjustments of type `opname`. #stock (agent, unconfirmed)
